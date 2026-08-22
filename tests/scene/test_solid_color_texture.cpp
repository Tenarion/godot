/**************************************************************************/
/*  test_solid_color_texture.cpp                                          */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "core/math/color.h"
#include "tests/test_macros.h"

TEST_FORCE_LINK(test_solid_color_texture)

#include "scene/resources/solid_color_texture.h"

namespace TestSolidColorTexture {

// [SceneTree] in a test case name enables initializing a mock render server,
// which ImageTexture is dependent on.
TEST_CASE("[SceneTree][SolidColorTexture2D] Create SolidColorTexture2D") {
	Ref<SolidColorTexture2D> solid_color_texture = memnew(SolidColorTexture2D);

	Color test_color = Color::hex(0xff00ffff);
	solid_color_texture->set_color(test_color);
	CHECK(solid_color_texture->get_color() == test_color);

	solid_color_texture->set_use_hdr(true);
	CHECK(solid_color_texture->is_using_hdr());
}

} // namespace TestSolidColorTexture
