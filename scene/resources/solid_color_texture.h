/**************************************************************************/
/*  solid_color_texture.h												  */
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

#pragma once

#include "core/math/color.h"
#include "core/object/object.h"
#include "scene/resources/texture.h"

class SolidColorTexture2D : public Texture2D {
	GDCLASS(SolidColorTexture2D, Texture2D);

private:
	Color color = Color(1, 1, 1);
	mutable bool update_pending = false;
	mutable RID texture;
	bool use_hdr = false;

	void _queue_update();
	void _update() const;

protected:
	static void _bind_methods();

public:
	void set_color(const Color &p_color);
	Color get_color() const;

	void set_use_hdr(bool p_enabled);
	bool is_using_hdr() const;

	virtual RID get_rid() const override;
	virtual int get_width() const override { return 1; }
	virtual int get_height() const override { return 1; }
	virtual bool has_alpha() const override { return true; }

	virtual Ref<Image> get_image() const override;
	void update_now() const;

	SolidColorTexture2D();
	virtual ~SolidColorTexture2D();
};
