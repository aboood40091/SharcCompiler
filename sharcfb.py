#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import struct

import gsh
gx2shader = gsh.gx2shader
roundUp = gx2shader.roundUp

from sharc import ShaderProgramBase, ListBase


supported_versions = 8,


class Header:
    def __init__(self, endianness='<'):
        self.format = '4I4xI'
        self.endianness = endianness

        self.magic = 0x53484142  # SHAB
        self.version = 8
        self.fileSize = 0
        self.name = ''

    def load(self, data, pos=0):
        (self.magic,
         self.version,
         self.fileSize,
         endianness,
         nameLen) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        assert self.magic == 0x53484142
        assert endianness == 1

        size = struct.calcsize(self.format)
        pos += size

        self.name = data[pos:pos + nameLen].decode('utf-8').rstrip('\0')
        self.size = size + nameLen

        assert self.version in supported_versions

    def save(self):
        name = self.name.encode('utf-8') + b'\0'

        return b''.join([
            struct.pack(
                '%s%s' % (self.endianness, self.format),
                self.magic,
                self.version,
                0,
                1,
                len(name),
            ),
            name,
        ])


class ShaderBinary:
    def __init__(self, endianness='<'):
        self.format = '4I'
        self.endianness = endianness

        self.size = 0
        self.type = 0
        self.binary = None

    def __str__(self):
        return 'Shader Binary'

    def load(self, data, pos):
        (self.size,
         self.type,
         binaryOffs,
         binaryLen) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        assert self.type in (0, 1)

        pos += struct.calcsize(self.format) + binaryOffs
        self.binary = gx2shader.GX2VertexShader(self.endianness) if self.type == 0 else gx2shader.GX2PixelShader(self.endianness)
        shaderSize, shaderOffs = self.binary.getShaderSizeAndOffset(data, pos)

        assert shaderOffs + shaderSize == binaryLen
        self.binary.load(data, pos, data[pos + shaderOffs:pos + shaderOffs + shaderSize])

    def save(self, pos):
        binaryPos = pos + struct.calcsize(self.format)
        binary = bytearray(self.binary.save())
        binary += b'\0' * (roundUp(binaryPos + len(binary), 0x100) - binaryPos - len(binary))

        binary[self.binary.getRegsLength() + 4:self.binary.getRegsLength() + 8] = struct.pack('%sI' % self.endianness, len(binary))
        binary += self.binary.shader

        return  b''.join([
            struct.pack(
                '%s%s' % (self.endianness, self.format),
                struct.calcsize(self.format) + len(binary),
                self.type,
                0,
                len(binary),
            ),
            binary,
        ])


class ShaderProgram:
    def __init__(self, endianness='<'):
        self.format = '3Ii'
        self.endianness = endianness

        self.size = 0
        self.kind = 0
        self.baseIndex = -1

        self.variations = List(self.endianness)
        self.variationSymbols = List(self.endianness)

        self.uniformVariables = List(self.endianness)
        self.uniformBlocks = List(self.endianness)
        self.samplerVariables = List(self.endianness)
        self.attribVariables = List(self.endianness)

        self.name = ''

    def __str__(self):
        return 'Shader Program Binary'

    def load(self, data, pos):
        (self.size,
         nameLen,
         self.kind,
         self.baseIndex) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        pos += struct.calcsize(self.format)
        self.name = data[pos:pos + nameLen].decode('utf-8').rstrip('\0')

        pos += nameLen
        self.variations.load(data, pos, ShaderProgramBase.VariationMacro)

        pos += self.variations.size
        self.variationSymbols.load(data, pos, ShaderProgramBase.VariationSymbol)

        pos += self.variationSymbols.size
        self.uniformVariables.load(data, pos, ShaderProgramBase.ShaderSymbol)

        pos += self.uniformVariables.size
        self.uniformBlocks.load(data, pos, ShaderProgramBase.ShaderSymbol)

        pos += self.uniformBlocks.size
        self.samplerVariables.load(data, pos, ShaderProgramBase.ShaderSymbol)

        pos += self.samplerVariables.size
        self.attribVariables.load(data, pos, ShaderProgramBase.ShaderSymbol)

    def save(self):
        name = self.name.encode('utf-8') + b'\0'

        variations = self.variations.save()
        variationSymbols = self.variationSymbols.save()
        uniformVariables = self.uniformVariables.save()
        uniformBlocks = self.uniformBlocks.save()
        samplerVariables = self.samplerVariables.save()
        attribVariables = self.attribVariables.save()

        return b''.join([
            struct.pack(
                '%s%s' % (self.endianness, self.format),
                struct.calcsize(self.format) + len(name) + len(variations) + len(variationSymbols) + len(uniformVariables) + len(uniformBlocks) + len(samplerVariables) + len(attribVariables),
                len(name),
                self.kind,
                self.baseIndex,
            ),
            name,
            variations,
            variationSymbols,
            uniformVariables,
            uniformBlocks,
            samplerVariables,
            attribVariables,
        ])


class List(ListBase):
    def index(self, item):
        for i, oItem in enumerate(self.items):
            if item == oItem:
                return i

        return -1

    def save(self, *args):
        pos = struct.calcsize(self.format)
        outBuffer = bytearray()
        for i, item in enumerate(self):
            if isinstance(item, ShaderBinary):
                outBuffer += item.save(args[0] + pos + len(outBuffer))
            else:
                outBuffer += item.save()

        return b''.join([
            struct.pack(
                '%s%s' % (self.endianness, self.format),
                struct.calcsize(self.format) + len(outBuffer),
                self.len(),
            ),
            outBuffer,
        ])


def load(inb, pos=0):
    header = Header()
    header.load(inb, pos)

    pos += header.size

    binaryList = List()
    binaryList.load(inb, pos, ShaderBinary)

    pos += binaryList.size

    progList = List()
    progList.load(inb, pos, ShaderProgram)

    pos += progList.size

    return header, binaryList, progList


def save(header, binaryList, progList):
    headerB = header.save()
    outBuffer = bytearray(b''.join([
        headerB,
        binaryList.save(len(headerB)),
        progList.save(),
    ]))

    outBuffer[8:12] = struct.pack('%sI' % header.endianness, len(outBuffer))
    return outBuffer
