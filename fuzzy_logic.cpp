#include <filesystem>
#include <string>
#include <vector>
#include <algorithm>
#include <iostream>
#include <queue>
#include <cstdio>
#include <fstream>
#include <unordered_set>
#include <unistd.h>

namespace fs=std::filesystem;

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

// Drops any path `git` would consider ignored -- respecting .gitignore at
// every level, negation patterns, and global excludes -- by asking git
// itself rather than reimplementing gitignore semantics in C++. Falls back
// to returning the input unchanged when `curr` isn't inside a git work tree
// or git isn't available, since this tool must stay usable without git too.
std::vector<fs::path> filter_gitignored(const std::vector<fs::path> &candidates,
                                         const std::string &curr) {
  if (candidates.empty()) return candidates;

  fs::path temp_file = fs::temp_directory_path() /
      ("fuzzy_finder_" + std::to_string(getpid()) + ".paths");
  {
    std::ofstream out(temp_file);
    for (const auto &p : candidates) {
      out << p.string() << "\n";
    }
  }

  std::string cmd = "git -C " + shell_quote(curr) + " check-ignore --stdin < " +
                     shell_quote(temp_file.string()) + " 2>/dev/null";

  std::unordered_set<std::string> ignored;
  FILE *pipe = popen(cmd.c_str(), "r");
  if (pipe) {
    char buf[4096];
    while (fgets(buf, sizeof(buf), pipe)) {
      std::string line(buf);
      while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
        line.pop_back();
      }
      if (!line.empty()) ignored.insert(line);
    }
    pclose(pipe);
  }

  std::error_code rm_ec;
  fs::remove(temp_file, rm_ec);

  if (ignored.empty()) return candidates;

  std::vector<fs::path> result;
  result.reserve(candidates.size());
  for (const auto &p : candidates) {
    if (ignored.find(p.string()) == ignored.end()) {
      result.push_back(p);
    }
  }
  return result;
}

void find_files(std::vector<fs::path> &files, const std::string &curr) {
  const std::vector<std::string> exDir = {"build", ".git", ".venv"};
  fs::path base_dir{curr};

  // Use the error_code-based iterator API (rather than the throwing one) so
  // a problem in one subdirectory -- permission denied, a broken symlink --
  // is skipped in place instead of aborting the entire remaining walk.
  std::error_code ec;
  auto start = fs::recursive_directory_iterator(
      curr, fs::directory_options::skip_permission_denied, ec);
  auto end = fs::recursive_directory_iterator();

  if (ec) {
    std::cerr << "Error: " << ec.message() << "\n";
    return;
  }

  std::vector<fs::path> raw_files;
  while (start != end) {
    std::error_code type_ec;
    bool is_file = start->is_regular_file(type_ec);
    bool is_dir = !type_ec && start->is_directory(type_ec);

    if (!type_ec) {
      if (is_file) {
        raw_files.push_back(fs::relative(start->path(), base_dir));
      } else if (is_dir) {
        std::string dirName = start->path().filename().string();
        if (std::find(exDir.begin(), exDir.end(), dirName) != exDir.end()) {
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

  files = filter_gitignored(raw_files, curr);
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
                                      const std::string &query, size_t k) {
  std::priority_queue<ScoredMatch, std::vector<ScoredMatch>, MinHeapCompare> heap;

  for (const auto &file : files) {
    double score = fuzzy_score(file, query);
    if (score <= 0) continue;

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

  auto results = topKMatches(files, query, top_k);

  for (const auto &r : results) {
    std::cout << r.score << "\t" << r.path.string() << "\n";
  }

  return 0;
}
