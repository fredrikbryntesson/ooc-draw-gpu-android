//
// Copyright (c) 2011-2014 Simon Mika <simon@mika.se>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

use ooc-math
use ooc-draw
use ooc-draw-gpu
use ooc-base
use ooc-opengl
import math, EGLImage

GpuPacker: abstract class extends Surface {
	_packMonochrome: GpuMapPackMonochrome
	_packUv: GpuMapPackUv
	_renderTarget: Fbo
	_targetTexture: EGLImage
	_pyramidBuffer: UInt8*
	_context: Context
	init: func (context: Context) {
		this _packMonochrome = GpuMapPackMonochrome new()
		this _packUv = GpuMapPackUv new()
		this _quad = Quad create()
		this _pyramidBuffer = gc_malloc((1920 + 640) * 1080) as UInt8*
		this _context = context
	}
	dispose: func {
		this _targetTexture dispose()
		this _renderTarget dispose()
		this _packMonochrome dispose()
		this _packUv dispose()
		gc_free(this _pyramidBuffer)
	}
	pack: func ~monochrome (image: GpuMonochrome) -> UInt8* {
		this _packMonochrome transform = FloatTransform2D identity
		this _packMonochrome imageSize = image size
		this _packMonochrome screenSize = image size
		this draw(image, this _packMonochrome)
		result := this _targetTexture lock()
		result
	}
	pack: func ~uv (image: GpuUv) -> UInt8* {
		this _packUv transform = FloatTransform2D identity
		this _packUv imageSize = image size
		this _packUv screenSize = image size
		this draw(image, this _packUv)
		result := this _targetTexture lock()
		result
	}
	packPyramid: func ~monochrome (image: RasterMonochrome, count: Int) -> UInt8* {
		gpuMonochrome := GpuImage create(image)
		gpuMonochrome generateMipmap()
		this _packMonochrome transform = FloatTransform2D identity
		this _packMonochrome imageSize = image size
		this _packMonochrome screenSize = image size
		resolution := image size
		pyramidBuffer := this _pyramidBuffer
		for(i in 0..count) {
			resolution /= 2
			this draw(gpuMonochrome, this _packMonochrome, resolution)
			pixels := this _targetTexture lock() as UInt8*
			paddedBytes := 640 + 1920 - resolution width
			byteCount := (640 + 1920) * resolution height
			memcpy(pyramidBuffer, pixels, byteCount)
			pyramidBuffer += byteCount
			/*
			for(row in 0..resolution height) {
				memcpy(pyramidBuffer, pixels, resolution width)
				pyramidBuffer += resolution width
				pixels += resolution width + paddedBytes
			}
			*/
			this _targetTexture unlock()
		}
		gpuMonochrome recycle()
		this _pyramidBuffer
	}
	unlock: func {
		this _targetTexture unlock()
	}
	_bind: func {
		this _renderTarget bind()
	}
	_unbind: func {
		this _renderTarget unbind()
	}
	_clear: func {
		this _renderTarget clear()
	}
	_update: func {
		Fbo finish()
	}
}

GpuPackerY: class extends GpuPacker {
	init: func (context: Context) {
		super(context)
	}
	initialize: func (context: Context) {
		this _targetTexture = EGLImage new(context _eglDisplay, TextureType monochrome, IntSize2D new(1920 / 4, 1080))
		this _renderTarget = Fbo create(this _targetTexture texture, 1920 / 4, 1080)
	}

	create: static func (context: Context) -> This {
		result := This new(context)
		result initialize(context)
		result
	}
	_setResolution: func (resolution: IntSize2D) {
		Fbo setViewport(0, 0, resolution width / 4, resolution height)
	}
}

GpuPackerUv: class extends GpuPacker {
	init: func (context: Context) {
		super(context)
	}
	initialize: func (context: Context) {
		this _targetTexture = EGLImage new(context _eglDisplay, TextureType uv, IntSize2D new(1920 / 4, 1080 / 2))
		this _renderTarget = Fbo create(this _targetTexture texture, 1920 / 2, 1080 / 2)
	}
	create: static func (context: Context) -> This {
		result := This new(context)
		result initialize(context)
		result
	}
	_setResolution: func (resolution: IntSize2D) {
		Fbo setViewport(0, 0, resolution width / 2, resolution height)
	}
}

GpuPackerU: class extends GpuPacker {
	init: func (context: Context) {
		super(context)
	}
	initialize: func (context: Context) {
		this _targetTexture = EGLImage new(context _eglDisplay, TextureType monochrome, IntSize2D new(1920 / 4, 1080 / 4))
		this _renderTarget = Fbo create(this _targetTexture texture, 1920 / 4, 1080 / 4)
	}
	create: static func (context: Context) -> This {
		result := This new(context)
		result initialize(context)
		result
	}
	_setResolution: func (resolution: IntSize2D) {
		Fbo setViewport(0, 0, resolution width / 4, resolution height / 4)
	}
}
