#ifndef DLDT_TOOLS_CATCH2_CATCH2_GLM_HPP_
#define DLDT_TOOLS_CATCH2_CATCH2_GLM_HPP_

#include <catch2/catch_test_macros.hpp>
#include <glm/glm.hpp>
#include <glm/gtx/string_cast.hpp>

namespace Catch {
template <typename genType, int N>
struct StringMaker<glm::vec<N, genType>> {
  static std::string convert(glm::vec<N, genType> const& value) { return glm::to_string(value); }
};

template <typename genType, int N>
struct StringMaker<glm::mat<N, N, genType>> {
  static std::string convert(glm::mat<N, N, genType> const& value) { return glm::to_string(value); }
};

template <typename genType>
struct StringMaker<glm::tquat<genType>> {
  static std::string convert(glm::tquat<genType> const& value) { return glm::to_string(value); }
};
}  // namespace Catch

#endif  // DLDT_TOOLS_CATCH2_CATCH2_GLM_HPP_
