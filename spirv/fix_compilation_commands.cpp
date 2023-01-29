#include <argparse/argparse.hpp>
#include <fmt/format.h>
#include <fmt/std.h>
#include <fmt/os.h>
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
const auto kBuildFileOutArg = "build-out-file"s;
const auto kBuildFileInArg = "build-in-file"s;
const auto kDependenciesFileOutArg = "dependencies-out-file"s;
const auto kDependenciesFileInArg = "dependencies-in-file"s;


argparse::ArgumentParser BuildArgumentParser() {
  argparse::ArgumentParser program("fix-compilation-commands");

  program.add_argument(kLocationsFilePathArg)
      .help(
          "path to the locations.json file. This file must "
          "contain current workspace location")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kBuildFileOutArg)
      .help("path to where the fixed compilation commands file to be saved")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kBuildFileInArg)
      .help("path to the fixed compilation commands is to be fixed")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kDependenciesFileOutArg)
      .help("path to where the dependency file is to be saved")
      .required()
      .action([](const std::string &value) { return stdfs::path(value); });

  program.add_argument(kDependenciesFileInArg)
      .help("path to the dependency file to be fixed")
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

  const auto buildOutFilePath = program.get<stdfs::path>(kBuildFileOutArg);

  const auto buildInFilePath = program.get<stdfs::path>(kBuildFileInArg);
  if (!stdfs::exists(buildInFilePath) || !stdfs::is_regular_file(buildInFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", buildInFilePath);
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

  const auto dependenciesOutFilePath = program.get<stdfs::path>(kDependenciesFileOutArg);

  const auto dependenciesInFilePath = program.get<stdfs::path>(kDependenciesFileInArg);
  if (!stdfs::exists(dependenciesInFilePath) || !stdfs::is_regular_file(dependenciesInFilePath)) {
    fmt::print(std::cerr, "{0} does not exist or is not a valid file.\n", dependenciesInFilePath);
    return Fail(std::make_error_code(std::errc::no_such_file_or_directory));
  }

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

    {
      std::ifstream ifs(buildInFilePath);
      std::ofstream ofs(buildOutFilePath);
      ofs << bazelExecutionRoot.string() << "\n";
      ofs << ifs.rdbuf();
    }

    {
      std::ifstream ifs(dependenciesInFilePath);
      std::ofstream ofs(dependenciesOutFilePath);
      std::vector<std::string> entries((std::istream_iterator<std::string>(ifs)), std::istream_iterator<std::string>());
      fmt::print(ofs, "{}{}", bazelExecutionRoot.string() + "/", fmt::join(entries, " "s + bazelExecutionRoot.string() + "/"));
    }

  }

  return EXIT_SUCCESS;
}
