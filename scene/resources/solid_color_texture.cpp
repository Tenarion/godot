/**************************************************************************/
/*  solid_color_texture.cpp												  */
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

#include "scene/resources/solid_color_texture.h"

#include "core/io/image.h"
#include "core/math/color.h"
#include "core/object/callable_mp.h"
#include "core/object/class_db.h"
#include "core/os/memory.h"
#include "servers/rendering/rendering_server.h"

SolidColorTexture2D::SolidColorTexture2D() {
	_queue_update();
}

SolidColorTexture2D::~SolidColorTexture2D() {
	if (texture.is_valid()) {
		ERR_FAIL_NULL(RenderingServer::get_singleton());
		RS::get_singleton()->free_rid(texture);
	}
}

void SolidColorTexture2D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_color", "color"), &SolidColorTexture2D::set_color);
	ClassDB::bind_method(D_METHOD("get_color"), &SolidColorTexture2D::get_color);

	ClassDB::bind_method(D_METHOD("set_use_hdr", "enabled"), &SolidColorTexture2D::set_use_hdr);
	ClassDB::bind_method(D_METHOD("is_using_hdr"), &SolidColorTexture2D::is_using_hdr);

	ADD_PROPERTY(PropertyInfo(Variant::COLOR, "color"), "set_color", "get_color");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_hdr"), "set_use_hdr", "is_using_hdr");
}

void SolidColorTexture2D::set_color(const Color &p_color) {
	if (p_color == color) {
		return;
	}

	color = p_color;

	_queue_update();
	emit_changed();
}

Color SolidColorTexture2D::get_color() const {
	return color;
}

void SolidColorTexture2D::_queue_update() {
	if (update_pending) {
		return;
	}
	update_pending = true;
	callable_mp(this, &SolidColorTexture2D::update_now).call_deferred();
}

void SolidColorTexture2D::_update() const {
	update_pending = false;

	if (use_hdr) {
		// High dynamic range.
		Ref<Image> image = memnew(Image(1, 1, false, Image::FORMAT_RGBAF));

		// `create()` isn't available for non-uint8_t data, so fill in the data manually.
		image->set_pixel(0, 0, color);

		if (texture.is_valid()) {
			RID new_texture = RS::get_singleton()->texture_2d_create(image);
			RS::get_singleton()->texture_replace(texture, new_texture);
		} else {
			texture = RS::get_singleton()->texture_2d_create(image);
		}
	} else {
		// Low dynamic range. "Overbright" colors will be clamped.
		Vector<uint8_t> data;
		data.resize(4);
		{
			uint8_t *wd8 = data.ptrw();
			wd8[0] = uint8_t(color.get_r8());
			wd8[1] = uint8_t(color.get_g8());
			wd8[2] = uint8_t(color.get_b8());
			wd8[3] = uint8_t(color.get_a8());
		}

		Ref<Image> image = memnew(Image(1, 1, false, Image::FORMAT_RGBA8, data));

		if (texture.is_valid()) {
			RID new_texture = RS::get_singleton()->texture_2d_create(image);
			RS::get_singleton()->texture_replace(texture, new_texture);
		} else {
			texture = RS::get_singleton()->texture_2d_create(image);
		}
	}
	RS::get_singleton()->texture_set_path(texture, get_path());
}

void SolidColorTexture2D::set_use_hdr(bool p_enabled) {
	if (p_enabled == use_hdr) {
		return;
	}

	use_hdr = p_enabled;
	_queue_update();
	emit_changed();
}

bool SolidColorTexture2D::is_using_hdr() const {
	return use_hdr;
}

RID SolidColorTexture2D::get_rid() const {
	if (!texture.is_valid()) {
		texture = RS::get_singleton()->texture_2d_placeholder_create();
	}
	return texture;
}

Ref<Image> SolidColorTexture2D::get_image() const {
	update_now();
	if (!texture.is_valid()) {
		return Ref<Image>();
	}
	return RenderingServer::get_singleton()->texture_2d_get(texture);
}

void SolidColorTexture2D::update_now() const {
	if (update_pending) {
		_update();
	}
}
