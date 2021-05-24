#include <argparse/argparse.hpp>
#include <fmt/printf.h>
#include <nlohmann/json.hpp>

#include <array>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

using namespace std::literals::string_literals;

namespace stdfs = std::filesystem;

const auto kBazelStableStatusFilePathArg = "-b"s;
const auto kBazelStableStatusFilePathArgLong = "--bazel-stable-status-file"s;
const auto kCompileCommandsFileInArg = "compile-commands-in-file"s;
const auto kCompileCommandsFileOutArg = "compile-commands-out-file"s;

argparse::ArgumentParser BuildArgumentParser() {
  argparse::ArgumentParser program("fix-compilation-db");

  program.add_argument(kBazelStableStatusFilePathArg, kBazelStableStatusFilePathArgLong)
      .help(
          "path to the bazel workspace stable status file. This file must "
          "contain current workspace location defined as "
          "STABLE_EXECUTION_ROOT_FOR_COMPILATION_DATABASE")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kCompileCommandsFileOutArg)
      .help("path to where the fixed compilation database is to be saved")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kCompileCommandsFileInArg)
      .help("path to the clang compilation database to be fixed")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  return program;
}

int Fail(std::error_code ec) {
  fmt::print(std::cerr, "{}\n", ec.message());
  return EXIT_FAILURE;
}

int main(int argc, char *argv[]) {
  using nlohmann::json;

  auto program = BuildArgumentParser();
  try {
    program.parse_args(argc, argv);
  } catch (const std::runtime_error &err) {
    fmt::print(std::cerr, "{0}\n", err.what());
    return Fail(std::make_error_code(std::errc::invalid_argument));
  }

  const auto bazelStableStatusFilePath = program.get<stdfs::path>(kBazelStableStatusFilePathArg);
  if (!stdfs::exists(bazelStableStatusFilePath) || !stdfs::is_regular_file(bazelStableStatusFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", bazelStableStatusFilePath.string());
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

  const auto clangDBInFilePath = program.get<stdfs::path>(kCompileCommandsFileInArg);
  if (!stdfs::exists(clangDBInFilePath) || !stdfs::is_regular_file(clangDBInFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", clangDBInFilePath.string());
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

  const auto clangDBOutFilePath = program.get<stdfs::path>(kCompileCommandsFileOutArg);

  stdfs::path bazelStableWorkspaceRoot;
  stdfs::path bazelStableExecutionRoot;
  {
    json locations;
    {
      std::ifstream ifs(bazelStableStatusFilePath);
      ifs >> locations;
    }

    bazelStableWorkspaceRoot = locations["workspace_root"].get<std::string>();
    bazelStableExecutionRoot = locations["execution_root"].get<std::string>();
  }

  std::string bazelStableExecutionRootMarker = "@EXECUTION_ROOT@";
  {
    std::vector<std::string> lines;
    std::ifstream ifs(bazelStableStatusFilePath);
    if (ifs) {
      std::string line;
      while (std::getline(ifs, line)) {
        auto endIdx = line.find_first_of(" ");
        auto name = line.substr(0, endIdx);
        if (name == "STABLE_EXECUTION_ROOT_FOR_COMPILATION_DATABASE") {
          bazelStableWorkspaceRoot = stdfs::path(line.substr(endIdx + 1));
          break;
        } else if (name == "STABLE_WORKSPACE_ROOT_FOR_COMPILATION_DATABASE") {
          bazelStableWorkspaceRoot = stdfs::path(line.substr(endIdx + 1));
          break;
        }
      }
    }

    if (!stdfs::exists(bazelStableWorkspaceRoot) || !stdfs::is_directory(bazelStableWorkspaceRoot)) {
      fmt::print(std::cerr, "bazel workspace root {0} does not exist or cannot be read\n",
                 bazelStableWorkspaceRoot.string());
      return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
    }

    if (!stdfs::exists(bazelStableExecutionRoot) || !stdfs::is_directory(bazelStableExecutionRoot)) {
      fmt::print(std::cerr, "bazel execution root {0} does not exist or cannot be read\n",
                 bazelStableExecutionRoot.string());
      return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
    }

    auto bazelStableExecutionRootStr = bazelStableExecutionRoot.string();
    json compilationDB;
    {
      std::ifstream ifs(clangDBInFilePath);
      ifs >> compilationDB;
    }
    for (auto &entry : compilationDB) {
      entry["directory"] = bazelStableWorkspaceRoot.string();
      auto &arguments = entry["arguments"];
      auto it = std::find(arguments.begin(), arguments.end(), "-fno-canonical-system-headers");
      if (it != arguments.end()) {
        arguments.erase(it);
      }
      it = std::find(arguments.begin(), arguments.end(), "/showIncludes");
      if (it != arguments.end()) {
        arguments.erase(it);
      }

      for (auto &argument : arguments) {
        if (argument.is_string()) {
          decltype(auto) stringref = argument.get_ref<std::string &>();
          if (auto pos = stringref.find(bazelStableExecutionRootMarker); pos != std::string::npos) {
            stringref.replace(pos, bazelStableExecutionRootMarker.size(), bazelStableExecutionRootStr);
          }
        }
      }
    }
    {
      std::ofstream ofs(clangDBOutFilePath);
      ofs << compilationDB;
    }
  }

  return EXIT_SUCCESS;
}