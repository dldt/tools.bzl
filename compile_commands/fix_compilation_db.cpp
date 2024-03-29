#include <argparse/argparse.hpp>
#include <fmt/format.h>
#include <fmt/ostream.h>
#include <fmt/std.h>
#include <nlohmann/json.hpp>

#include <array>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

using namespace std::literals::string_literals;

namespace stdfs = std::filesystem;

const auto kLocationsFilePathArg = "locations-file"s;
const auto kCompileCommandsFileInArg = "compile-commands-in-file"s;
const auto kCompileCommandsFileOutArg = "compile-commands-out-file"s;

argparse::ArgumentParser BuildArgumentParser() {
  argparse::ArgumentParser program("fix-compilation-db");

  program.add_argument(kLocationsFilePathArg)
      .help(
          "path to the locations.json file. This file must "
          "contain current workspace location defined")
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

  const auto locationsFilePath = program.get<stdfs::path>(kLocationsFilePathArg);
  if (!stdfs::exists(locationsFilePath) || !stdfs::is_regular_file(locationsFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", locationsFilePath);
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

  const auto clangDBInFilePath = program.get<stdfs::path>(kCompileCommandsFileInArg);
  if (!stdfs::exists(clangDBInFilePath) || !stdfs::is_regular_file(clangDBInFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", clangDBInFilePath);
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

  const auto clangDBOutFilePath = program.get<stdfs::path>(kCompileCommandsFileOutArg);

  stdfs::path bazelWorkspaceRoot;
  stdfs::path bazelExecutionRoot;
  {
    json locations;
    {
      std::ifstream ifs(locationsFilePath);
      ifs >> locations;
    }

    bazelWorkspaceRoot = locations["workspace_root"].get<std::string>();
    bazelExecutionRoot = locations["execution_root"].get<std::string>();
  }

  std::string bazelStableExecutionRootMarker = "@EXECUTION_ROOT@";
  {
    if (!stdfs::exists(bazelWorkspaceRoot) || !stdfs::is_directory(bazelWorkspaceRoot)) {
      fmt::print(std::cerr, "bazel workspace root {0} does not exist or cannot be read\n",
                 bazelWorkspaceRoot);
      return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
    }

    if (!stdfs::exists(bazelExecutionRoot) || !stdfs::is_directory(bazelExecutionRoot)) {
      fmt::print(std::cerr, "bazel execution root {0} does not exist or cannot be read\n",
                 bazelExecutionRoot);
      return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
    }

    auto bazelStableExecutionRootStr = bazelExecutionRoot.string();
    json compilationDB;
    {
      std::ifstream ifs(clangDBInFilePath);
      ifs >> compilationDB;
    }
    for (auto &entry : compilationDB) {
      entry["directory"] = bazelWorkspaceRoot.string();
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
