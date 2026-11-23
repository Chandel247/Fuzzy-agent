#include <filesystem>
#include <string>
#include <vector>
#include <algorithm>
#include <iostream>
#include <queue>
#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <iomanip>
#include <unordered_set>
#include <sys/wait.h>

namespace fs=std::filesystem;

// Directory names that are never searched, in either listing mode.
static const std::vector<std::string> kAlwaysSkipped = {"build", ".git", ".venv"};
// Extra directories skipped by the fallback walk only. Inside a git work
// tree, .gitignore decides instead (they are almost always ignored anyway).
static const std::vector<std::string> kWalkSkipped = {"build", ".git", ".venv",
                                                       "node_modules", "__pycache__"};

// Single-quotes a string for safe embedding in a shell command line.
std::string shell_quote(const std::string &value) {
  std::string quoted = "'";
  for (char c : value) {
    if (c == '\'') {
      quoted += "'\\''";
    } else {
      quoted += c;
    }
  }
  quoted += "'";
  return quoted;
}

// Runs `cmd` through the shell and captures all of its stdout (binary-safe,
// so NUL-separated output survives). Returns true only if the command could
// be started and exited with status 0.
bool run_capture(const std::string &cmd, std::string &out) {
  out.clear();
  FILE *pipe = popen(cmd.c_str(), "r");
  if (!pipe) return false;
  char buf[65536];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), pipe)) > 0) {
    out.append(buf, n);
  }
  int status = pclose(pipe);
  return status != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

// True if `dir` is inside a git work tree and the git CLI is available.
bool is_git_work_tree(const std::string &dir) {
  std::string out;
  std::string cmd = "git -C " + shell_quote(dir) +
                    " rev-parse --is-inside-work-tree 2>/dev/null";
  if (!run_capture(cmd, out)) return false;
  while (!out.empty() && (out.back() == '\n' || out.back() == '\r')) out.pop_back();
  return out == "true";
}

// True if any '/'-separated component of `rel` is one of `names`.
bool has_skipped_component(const std::string &rel,
                           const std::vector<std::string> &names) {
  size_t start = 0;
  while (start <= rel.size()) {
    size_t end = rel.find('/', start);
    if (end == std::string::npos) end = rel.size();
    std::string component = rel.substr(start, end - start);
    if (std::find(names.begin(), names.end(), component) != names.end()) return true;
    start = end + 1;
  }
  return false;
}

// Lists candidate files via `git ls-files`: tracked files plus untracked
// files that aren't ignored, with every .gitignore level, negations, and
// global excludes applied by git itself. Ignored trees like node_modules/
// are never even visited. Paths come back relative to `dir`. Output is
// NUL-separated (-z) so names containing newlines survive. Returns false
// if git fails, so the caller can fall back to walking the tree.
bool git_list_files(std::vector<fs::path> &files, const std::string &dir) {
  std::string out;
  std::string cmd = "git -C " + shell_quote(dir) +
                    " ls-files -z --cached --others --exclude-standard 2>/dev/null";
  if (!run_capture(cmd, out)) return false;

  // Unmerged (conflicted) paths are listed once per stage; dedupe them.
  std::unordered_set<std::string> seen;
  size_t start = 0;
  while (start < out.size()) {
    size_t end = out.find('\0', start);
    if (end == std::string::npos) end = out.size();
    std::string rel = out.substr(start, end - start);
    start = end + 1;
    if (rel.empty() || has_skipped_component(rel, kAlwaysSkipped)) continue;
    if (!seen.insert(rel).second) continue;
    files.push_back(fs::path(rel));
  }
  return true;
}

// Fallback for non-git directories (or when git is unavailable): walk the
// tree, pruning kWalkSkipped directories.
void walk_files(std::vector<fs::path> &files, const std::string &curr) {
  // The iterator is rooted at base_dir itself, so every entry's path() is
  // base_dir / <relative part> and lexically_relative recovers that part
  // with pure string work (no per-file realpath syscalls, unlike
  // fs::relative). Verified clean for ".", "src", "src/", "./src", and
  // absolute roots -- no "./" prefixes.
  const fs::path base_dir{curr};

  // Use the error_code-based iterator API (rather than the throwing one) so
  // a problem in one subdirectory -- permission denied, a broken symlink --
  // is skipped in place instead of aborting the entire remaining walk.
  std::error_code ec;
  auto start = fs::recursive_directory_iterator(
      base_dir, fs::directory_options::skip_permission_denied, ec);
  auto end = fs::recursive_directory_iterator();

  if (ec) {
    std::cerr << "Error: " << ec.message() << "\n";
    return;
  }

  while (start != end) {
    std::error_code type_ec;
    bool is_file = start->is_regular_file(type_ec);
    bool is_dir = !type_ec && start->is_directory(type_ec);

    if (!type_ec) {
      if (is_file) {
        files.push_back(start->path().lexically_relative(base_dir));
      } else if (is_dir) {
        std::string dirName = start->path().filename().string();
        if (std::find(kWalkSkipped.begin(), kWalkSkipped.end(), dirName) !=
            kWalkSkipped.end()) {
          start.disable_recursion_pending();
        }
      }
    }

    start.increment(ec);
    if (ec) {
      std::cerr << "Error: " << ec.message() << "\n";
      ec.clear();
    }
  }
}

// Inside a git work tree, list files with `git ls-files` (fast, and
// .gitignore-aware without walking ignored trees). Otherwise, or if git
// fails, walk the directory. Note that ls-files output can include tracked
// files deleted from disk and submodule directories; those are filtered
// out later, only for the final top-K results (see select_results).
void find_files(std::vector<fs::path> &files, const std::string &curr) {
  if (is_git_work_tree(curr) && git_list_files(files, curr)) return;
  files.clear();
  walk_files(files, curr);
}

// --- Fuzzy matching -----------------------------------------------------
// Scores a candidate path against the query. The candidate string is the
// whole relative path with '/' separators, so a query like "auth/user" can
// match across directories. Every query character must match, in order,
// case-insensitively (ASCII case folding only). Among all such alignments
// the one with the HIGHEST total score is used (fzf-style dynamic
// programming), not the greedy first-occurrence alignment. Each matched
// character earns:
//   +1.0  base
//   +0.8  exact case match
//   +0.6  the previous query char matched the position right before it
//   +0.5  word boundary: string start, after / _ - . or space, or a
//         lowercase->uppercase (camelCase) transition
//   +1.0  inside the filename (after the last '/')
// Then a bounded depth penalty is subtracted.
class FuzzyMatcher {
 public:
  static constexpr size_t kMaxDpQuery = 64;
  static constexpr size_t kMaxDpPath = 1024;

  explicit FuzzyMatcher(const std::string &query) : query_(query) {
    lower_query_.reserve(query.size());
    for (char c : query) lower_query_.push_back(lower(c));
    // DP buffers are allocated once here and reused for every candidate.
    prev_match_.assign(kMaxDpPath, 0.0);
    prev_best_.assign(kMaxDpPath, 0.0);
    cur_match_.assign(kMaxDpPath, 0.0);
    cur_best_.assign(kMaxDpPath, 0.0);
  }

  // Returns 0 if some query character can't be matched in order.
  double score(const std::string &path) {
    const size_t m = query_.size();
    const size_t n = path.size();
    if (m == 0 || m > n) return 0;

    // Cheap pre-filter (rejects most candidates): greedy, case-insensitive
    // subsequence check. While at it, record each query char's earliest
    // feasible position, which bounds the DP below.
    size_t qi = 0;
    for (size_t j = 0; j < n && qi < m; ++j) {
      if (lower(path[j]) == lower_query_[qi]) {
        if (qi < kMaxDpQuery) lo_[qi] = j;
        ++qi;
      }
    }
    if (qi < m) return 0;

    size_t last_slash = path.rfind('/');
    size_t filename_start = (last_slash == std::string::npos) ? 0 : last_slash + 1;

    double score = (m > kMaxDpQuery || n > kMaxDpPath)
                       ? greedy_score(path, filename_start)
                       : best_alignment_score(path, filename_start);

    // Prefer shallower paths, but only as a ranking tie-breaker: cap the
    // depth penalty so it can never erase a genuine match by driving the
    // score to <= 0.
    int level_counter = static_cast<int>(std::count(path.begin(), path.end(), '/'));
    double depth_penalty = 0.1 * std::max(0, level_counter - 1);
    score -= std::min(depth_penalty, score * 0.5);
    return score;
  }

 private:
  static char lower(char c) {
    // Cast first: UTF-8 bytes are negative as plain char, and passing a
    // negative value to tolower is undefined behaviour.
    return static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }

  static bool is_boundary(const std::string &path, size_t j) {
    if (j == 0) return true;
    char prev = path[j - 1];
    if (prev == '/' || prev == '_' || prev == '-' || prev == '.' || prev == ' ')
      return true;
    char cur = path[j];
    return prev >= 'a' && prev <= 'z' && cur >= 'A' && cur <= 'Z';
  }

  // Score for query[i] matched at path[j], excluding the contiguity bonus.
  double char_score(const std::string &path, size_t i, size_t j,
                    size_t filename_start) const {
    double s = 1.0;
    if (query_[i] == path[j]) s += 0.8;
    if (is_boundary(path, j)) s += 0.5;
    if (j >= filename_start) s += 1.0;
    return s;
  }

  // Fallback for oversized inputs: the same per-character bonuses, applied
  // along the greedy first-occurrence alignment. Keeps huge queries/paths
  // linear-time. Assumes the pre-filter already confirmed a match.
  double greedy_score(const std::string &path, size_t filename_start) const {
    double s = 0;
    size_t qi = 0;
    size_t prev = std::string::npos;
    for (size_t j = 0; j < path.size() && qi < query_.size(); ++j) {
      if (lower(path[j]) != lower_query_[qi]) continue;
      s += char_score(path, qi, j, filename_start);
      if (prev != std::string::npos && j == prev + 1) s += 0.6;
      prev = j;
      ++qi;
    }
    return s;
  }

  // Two-row DP over (query index i, path index j):
  //   match[i][j] = best score with query[i] matched exactly at path[j]
  //   best[i][j]  = max over j' <= j of match[i][j']
  //   match[i][j] = char_score(i, j) + max(best[i-1][j-1],
  //                                        match[i-1][j-1] + 0.6)
  // Row i only needs columns lo[i]..hi[i] (earliest/latest feasible
  // positions from greedy forward/backward scans), which keeps the work
  // well below len(query) * len(path) in practice.
  double best_alignment_score(const std::string &path, size_t filename_start) {
    const size_t m = query_.size();
    const size_t n = path.size();
    const double kNone = -1e18;

    // Latest feasible position of each query char (backward greedy scan).
    size_t qi = m;
    for (size_t j = n; j-- > 0 && qi > 0;) {
      if (lower(path[j]) == lower_query_[qi - 1]) hi_[--qi] = j;
    }

    double *pm = prev_match_.data(), *pb = prev_best_.data();
    double *cm = cur_match_.data(), *cb = cur_best_.data();
    for (size_t i = 0; i < m; ++i) {
      double running = kNone;
      for (size_t j = lo_[i]; j <= hi_[i]; ++j) {
        double v = kNone;
        if (lower(path[j]) == lower_query_[i]) {
          double pred = kNone;
          if (i == 0) {
            pred = 0;
          } else {
            // lo[i] > lo[i-1] guarantees j - 1 >= lo[i-1].
            pred = pb[std::min(j - 1, hi_[i - 1])];
            if (j - 1 <= hi_[i - 1] && pm[j - 1] > kNone)
              pred = std::max(pred, pm[j - 1] + 0.6);
          }
          if (pred > kNone) v = pred + char_score(path, i, j, filename_start);
        }
        cm[j] = v;
        running = std::max(running, v);
        cb[j] = running;
      }
      std::swap(pm, cm);
      std::swap(pb, cb);
    }
    return pb[hi_[m - 1]];
  }

  std::string query_;
  std::string lower_query_;
  size_t lo_[kMaxDpQuery];
  size_t hi_[kMaxDpQuery];
  std::vector<double> prev_match_, prev_best_, cur_match_, cur_best_;
};

// --- Top-K retrieval: bounded min-heap ---------------------------------
// Keeps only the K highest-scoring files seen so far. Once the heap is
// full, a new candidate is only admitted if it beats the current worst
// entry (heap top), which is then evicted. This avoids sorting the full
// file list, which matters once find_files returns thousands of paths.

struct ScoredMatch {
  fs::path path;
  double score;
};

// Total order on matches: higher score first; on equal scores, shorter
// path first; then plain byte-wise path comparison. Used both for heap
// eviction and the final sort, so output never depends on walk order.
bool ranks_before(const ScoredMatch &a, const ScoredMatch &b) {
  if (a.score != b.score) return a.score > b.score;
  const std::string &pa = a.path.native();
  const std::string &pb = b.path.native();
  if (pa.size() != pb.size()) return pa.size() < pb.size();
  return pa < pb;
}

struct MinHeapCompare {
  // priority_queue keeps the "largest" element (per this comparator) at
  // top(). Treating better-ranked matches as "smaller" keeps the worst
  // match at top() so it's the one we evict first.
  bool operator()(const ScoredMatch &a, const ScoredMatch &b) const {
    return ranks_before(a, b);
  }
};

std::vector<ScoredMatch> topKMatches(const std::vector<fs::path> &files,
                                      const std::string &query, size_t k,
                                      const std::unordered_set<std::string> &excluded) {
  std::priority_queue<ScoredMatch, std::vector<ScoredMatch>, MinHeapCompare> heap;
  FuzzyMatcher matcher(query);

  for (const auto &file : files) {
    double score = matcher.score(file.generic_string());
    if (score <= 0) continue;
    if (!excluded.empty() && excluded.count(file.string())) continue;

    ScoredMatch m{file, score};
    if (heap.size() < k) {
      heap.push(std::move(m));
    } else if (ranks_before(m, heap.top())) {
      heap.pop();
      heap.push(std::move(m));
    }
  }

  std::vector<ScoredMatch> results;
  results.reserve(heap.size());
  while (!heap.empty()) {
    results.push_back(heap.top());
    heap.pop();
  }
  std::reverse(results.begin(), results.end());  // best match first
  return results;
}

// Picks the top-K matches that still exist on disk as regular files.
// Only the final candidates are stat'ed (not the whole list), which keeps
// this cheap. A little slack (K + 32) absorbs the occasional deleted file
// or submodule directory; if more than that fail, selection is rerun with
// the bad paths excluded until K valid files are found or none remain.
std::vector<ScoredMatch> select_results(const std::vector<fs::path> &files,
                                        const std::string &query, size_t k,
                                        const std::string &dir) {
  const size_t slack = 32;
  std::unordered_set<std::string> bad;
  fs::path base{dir};
  while (true) {
    auto candidates = topKMatches(files, query, k + slack, bad);
    std::vector<ScoredMatch> valid;
    valid.reserve(std::min(k, candidates.size()));
    for (auto &c : candidates) {
      if (valid.size() == k) break;
      std::error_code ec;
      if (fs::is_regular_file(base / c.path, ec)) {
        valid.push_back(std::move(c));
      } else {
        bad.insert(c.path.string());
      }
    }
    if (valid.size() == k || candidates.size() < k + slack) return valid;
  }
}

void print_usage(const char *prog) {
  std::cerr << "Usage: " << prog << " <query> [directory] [top_k]\n";
}

// Strictly parses top_k: a plain base-10 integer in [1, 100000], nothing
// else (rejects "", "abc", "0", "-5", "10x", out-of-range values).
bool parse_top_k(const char *text, size_t &out) {
  // Require a leading digit: strtol alone would accept " 5" and "+5".
  if (text == nullptr || *text < '0' || *text > '9') return false;
  errno = 0;
  char *end = nullptr;
  long value = std::strtol(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0') return false;
  if (value < 1 || value > 100000) return false;
  out = static_cast<size_t>(value);
  return true;
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    print_usage(argv[0]);
    return 1;
  }

  std::string query = argv[1];
  std::string dir = (argc >= 3) ? argv[2] : ".";
  size_t top_k = 15;
  if (argc >= 4 && !parse_top_k(argv[3], top_k)) {
    print_usage(argv[0]);
    std::cerr << "Error: top_k must be an integer from 1 to 100000 (got '"
              << argv[3] << "')\n";
    return 2;
  }

  std::vector<fs::path> files;
  find_files(files, dir);

  auto results = select_results(files, query, top_k, dir);

  std::cout << std::fixed << std::setprecision(2);
  for (const auto &r : results) {
    std::cout << r.score << "\t" << r.path.string() << "\n";
  }

  return 0;
}
