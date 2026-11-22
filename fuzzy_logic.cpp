#include <filesystem>
#include <string>
#include <vector>
#include <algorithm>
#include <iostream>
#include <queue>
#include <cstdio>
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

double fuzzy_score(const fs::path &file_obj, const std::string &query) {
  double score = 0;
  int last_match_pos = -2;
  int query_pointer = 0;
  int file_name_pointer = 0;
  std::string file_name = file_obj.filename().string();
  if (query.length() == 0)
    return 0;
  while (file_name_pointer != (int)file_name.length()) {
    char small_query = std::tolower(query[query_pointer]);
    char small_file_name = std::tolower(file_name[file_name_pointer]);
    if (small_query == small_file_name) {
      score++;
      if ((file_name_pointer - last_match_pos) == 1) {
        score += 0.6;
      }
      if (query[query_pointer] == file_name[file_name_pointer]) {
        score += 0.8;
      }
      last_match_pos = file_name_pointer;
      query_pointer++;
      if (query_pointer == (int)query.length()) {
        break;
      }
    }
    file_name_pointer++;
  }
  if (query_pointer < (int)query.length()) {
    return 0;
  }

  // Prefer shallower paths, but only as a ranking tie-breaker: cap the
  // depth penalty so it can never erase a genuine match by driving the
  // score to <= 0 (previously an unbounded per-level penalty made any
  // match unfindable past a path depth of ~10).
  std::string path_name = file_obj.string();
  int level_counter = std::count(path_name.begin(), path_name.end(), '/');
  double depth_penalty = 0.1 * std::max(0, level_counter - 1);
  score -= std::min(depth_penalty, score * 0.5);

  return score;
}

// --- Top-K retrieval: bounded min-heap ---------------------------------
// Keeps only the K highest-scoring files seen so far. Once the heap is
// full, a new candidate is only admitted if it beats the current worst
// entry (heap top), which is then evicted. This avoids sorting the full
// file list, which matters once find_files returns thousands of paths.

struct ScoredMatch {
  fs::path path;
  double score;
};

struct MinHeapCompare {
  // priority_queue is a max-heap by default; reversing the comparison
  // keeps the lowest score at top() so it's the one we evict first.
  bool operator()(const ScoredMatch &a, const ScoredMatch &b) const {
    return a.score > b.score;
  }
};

std::vector<ScoredMatch> topKMatches(const std::vector<fs::path> &files,
                                      const std::string &query, size_t k,
                                      const std::unordered_set<std::string> &excluded) {
  std::priority_queue<ScoredMatch, std::vector<ScoredMatch>, MinHeapCompare> heap;

  for (const auto &file : files) {
    double score = fuzzy_score(file, query);
    if (score <= 0) continue;
    if (!excluded.empty() && excluded.count(file.string())) continue;

    if (heap.size() < k) {
      heap.push({file, score});
    } else if (score > heap.top().score) {
      heap.pop();
      heap.push({file, score});
    }
  }

  std::vector<ScoredMatch> results;
  results.reserve(heap.size());
  while (!heap.empty()) {
    results.push_back(heap.top());
    heap.pop();
  }
  std::reverse(results.begin(), results.end());  // best score first
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

int main(int argc, char *argv[]) {
  if (argc < 2) {
    std::cerr << "Usage: " << argv[0] << " <query> [directory] [top_k]\n";
    return 1;
  }

  std::string query = argv[1];
  std::string dir = (argc >= 3) ? argv[2] : ".";
  size_t top_k = (argc >= 4) ? static_cast<size_t>(std::stoi(argv[3])) : 15;

  std::vector<fs::path> files;
  find_files(files, dir);

  auto results = select_results(files, query, top_k, dir);

  for (const auto &r : results) {
    std::cout << r.score << "\t" << r.path.string() << "\n";
  }

  return 0;
}
