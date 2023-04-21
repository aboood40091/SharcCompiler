#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import struct

import gx2shader


class GFDData:
    pass


class GFDHeader(struct.Struct):
    def __init__(self):
        super().__init__('>4s7I')

    def data(self, data, pos):
        (self.magic,
         self.size_,
         self.majorVersion,
         self.minorVersion,
         self.gpuVersion,
         self.alignMode,  # Unused in v6.0
         self.reserved1,
         self.reserved2) = self.unpack_from(data, pos)


class GFDBlockHeader(struct.Struct):
    def __init__(self):
        super().__init__('>4s7I')

    def data(self, data, pos):
        (self.magic,
         self.size_,
         self.majorVersion,
         self.minorVersion,
         self.type_,
         self.dataSize,
         self.id,
         self.typeIdx) = self.unpack_from(data, pos)


def readGFD(f):
    gfd = GFDData()

    header = GFDHeader()
    header.data(f, 0)

    if header.magic != b'Gfx2':
        raise ValueError("Invalid file header!")

    if header.majorVersion not in [6, 7]:
        raise ValueError("Unsupported GSH version!")

    if header.gpuVersion != 2:
        raise ValueError("Unsupported GPU version!")

    pos = header.size

    gfd.vtxHeader = None
    gfd.vtxData = None
    gfd.pixHeader = None
    gfd.pixData = None

    while pos < len(f):  # Loop through the entire file, stop if reached the end of the file.
        block = GFDBlockHeader()
        block.data(f, pos)

        if block.magic != b'BLK{':
            raise ValueError("Invalid block header!")

        pos += block.size

        if block.type_ == 3:
            if gfd.vtxHeader is not None: raise NotImplementedError("Reading multiple vertex shaders is not supported!")
            gfd.vtxHeader = f[pos:pos + block.dataSize]

        elif block.type_ == 5:
            if gfd.vtxData is not None: raise NotImplementedError("Reading multiple vertex shaders is not supported!")
            gfd.vtxData = f[pos:pos + block.dataSize]

        elif block.type_ == 6:
            if gfd.pixHeader is not None: raise NotImplementedError("Reading multiple pixel shaders is not supported!")
            gfd.pixHeader = f[pos:pos + block.dataSize]

        elif block.type_ == 7:
            if gfd.pixData is not None: raise NotImplementedError("Reading multiple pixel shaders is not supported!")
            gfd.pixData = f[pos:pos + block.dataSize]

        pos += block.dataSize

    if gfd.vtxHeader is None or gfd.vtxData is None: raise ValueError("Program missing vertex shader!")
    if gfd.pixHeader is None or gfd.pixData is None: raise ValueError("Program missing pixel shader!")

    return gfd


def getShaders(filename):
    with open(filename, "rb") as inf:
        inb = inf.read()

    gfd = readGFD(inb)

    vtx = gx2shader.GX2VertexShader()
    vtx.load(gfd.vtxHeader, 0, gfd.vtxData)

    pix = gx2shader.GX2PixelShader()
    pix.load(gfd.pixHeader, 0, gfd.pixData)

    return vtx, pix
