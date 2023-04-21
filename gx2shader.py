#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import struct


align = True  # Using this variable to identify if SharcFB's version of GX2*Shader is being used (False = yes)


def roundUp(x, y):
    return ((x - 1) | (y - 1)) + 1


def readString(data, offset=0, charWidth=1, encoding='utf-8'):
    end = data.find(b'\0' * charWidth, offset)
    while end != -1:
        if (end - offset) % charWidth == 0:
            break
        end = data.find(b'\0' * charWidth, end + 1)

    if end == -1:
        return data[offset:].decode(encoding)

    return data[offset:end].decode(encoding)


class StringTable:
    class Entry:
        def __init__(self, value, pos):
            self.value = value
            self.pos = pos

    def __init__(self, offset):
        self.items = []
        self.data = bytearray()
        self.offset = offset

    def append(self, value):
        if align:
            self.data += b'\0' * (roundUp(len(self.data), 4) - len(self.data))

        entry = StringTable.Entry(value, len(self.data))
        self.data += value.encode('utf-8') + b'\0'
        self.items.append(entry)

    def getPos(self, value):
        for entry in self.items:
            if entry.value == value:
                return self.offset + entry.pos

        return -1

    def save(self):
        return bytes(self.data)


class GFDLoopVar:
    def __init__(self, endianness='>'):
        self.format = '2I'
        self.endianness = endianness

        self.offset = 0
        self.value = 0xFFFFFFFF

    def __repr__(self):
        return '(%d, %s)' % (self.offset, hex(self.value))

    def load(self, data, pos):
        (self.offset,
         self.value) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

    def save(self):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            self.offset,
            self.value,
        )


class GX2UniformBlock:
    def __init__(self, endianness='>'):
        self.format = '3I'
        self.endianness = endianness

        self.name = ''
        self.location = 0
        self.size = 0

    def load(self, data, pos, shaderPos):
        (nameOffs,
         self.location,
         self.size) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        self.name = readString(data, shaderPos + (nameOffs & ~0xCA700000))

    def save(self, nameOffs):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            nameOffs,
            self.location,
            self.size,
        )


class GX2UniformVar:
    def __init__(self, endianness='>'):
        self.format = '5I'
        self.endianness = endianness

        self.name = ''
        self.type = 0
        self.arrayCount = 0
        self.offset = 0
        self.blockIndex = 0

    def load(self, data, pos, shaderPos):
        (nameOffs,
         self.type,
         self.arrayCount,
         self.offset,
         self.blockIndex) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        self.name = readString(data, shaderPos + (nameOffs & ~0xCA700000))

    def save(self, nameOffs):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            nameOffs,
            self.type,
            self.arrayCount,
            self.offset,
            self.blockIndex,
        )


class GX2AttribVar:
    def __init__(self, endianness='>'):
        self.format = '4I'
        self.endianness = endianness

        self.name = ''
        self.type = 0
        self.arrayCount = 0
        self.location = 0

    def load(self, data, pos, shaderPos):
        (nameOffs,
         self.type,
         self.arrayCount,
         self.location) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        self.name = readString(data, shaderPos + (nameOffs & ~0xCA700000))

    def save(self, nameOffs):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            nameOffs,
            self.type,
            self.arrayCount,
            self.location,
        )


class GX2SamplerVar:
    def __init__(self, endianness='>'):
        self.format = '3I'
        self.endianness = endianness

        self.name = ''
        self.type = 0
        self.location = 0

    def load(self, data, pos, shaderPos):
        (nameOffs,
         self.type,
         self.location) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        self.name = readString(data, shaderPos + (nameOffs & ~0xCA700000))

    def save(self, nameOffs):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            nameOffs,
            self.type,
            self.location,
        )


class GX2RBuffer:
    def __init__(self, endianness='>'):
        self.format = '3I4x'
        self.endianness = endianness

        self.resourceFlags = 0
        self.elementSize = 0
        self.elementCount = 0

    def __repr__(self):
        return '(%s, %s, %d)' % (hex(self.resourceFlags), hex(self.elementSize), self.elementCount)

    def load(self, data, pos):
        (self.resourceFlags,
         self.elementSize,
         self.elementCount) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

    def save(self):
        return struct.pack(
            '%s%s' % (self.endianness, self.format),
            self.resourceFlags,
            self.elementSize,
            self.elementCount,
        )


class GX2VertexShader:
    def __init__(self, endianness='>'):
        self.format = '15I'
        self.endianness = endianness

        global align
        align = True if endianness == '>' else False

        self.shaderMode = 1
        self.ringItemSize = 0
        self.hasStreamOut = False
        self.streamOutStride = [0, 0, 0, 0]
        self.shaderRBuffer = None

        self.regs = []
        self.shader = b''
        self.uniformBlocks = []
        self.uniformVariables = []
        self.loopVariables = []
        self.samplerVariables = []
        self.attribVariables = []

    def getShaderSizeAndOffset(self, data, pos):
        return struct.unpack_from('%s2I' % self.endianness, data, pos + 208)

    def getRegsLength(self):
        return 208

    def load(self, data, pos, shader):
        pos_ = pos

        self.shader = shader
        self.regs = struct.unpack_from('%s52I' % self.endianness, data, pos)

        pos += 208  # regs size
        pos += 8    # shaderSize and shaderOffs

        (self.shaderMode,
         numUniformBlocks, uniformBlocksOffs,
         numUniformVariables, uniformVariablesOffs,
         numInitialValues, initialValuesOffs,
         numLoopVariables, loopVariablesOffs,
         numSamplerVariables, samplerVariablesOffs,
         numAttribVariables, attribVariablesOffs,
         self.ringItemSize,
         hasStreamOut) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        if numInitialValues: raise NotImplementedError("Initial values reading/saving is not implemented!")
        assert initialValuesOffs == 0

        pos += struct.calcsize(self.format)

        self.streamOutStride = struct.unpack_from('%s4I' % self.endianness, data, pos)
        pos += 16

        self.shaderRBuffer = GX2RBuffer(self.endianness)
        self.shaderRBuffer.load(data, pos)

        self.hasStreamOut = bool(hasStreamOut)

        pos = pos_ + (uniformBlocksOffs & ~0xD0600000)
        self.uniformBlocks = [GX2UniformBlock(self.endianness) for _ in range(numUniformBlocks)]
        for uniformBlock in self.uniformBlocks:
            uniformBlock.load(data, pos, pos_); pos += struct.calcsize(uniformBlock.format)

        pos = pos_ + (uniformVariablesOffs & ~0xD0600000)
        self.uniformVariables = [GX2UniformVar(self.endianness) for _ in range(numUniformVariables)]
        for uniformVariable in self.uniformVariables:
            uniformVariable.load(data, pos, pos_); pos += struct.calcsize(uniformVariable.format)

        pos = pos_ + (loopVariablesOffs & ~0xD0600000)
        self.loopVariables = [GFDLoopVar(self.endianness) for _ in range(numLoopVariables)]
        for loopVariable in self.loopVariables:
            loopVariable.load(data, pos); pos += struct.calcsize(loopVariable.format)

        pos = pos_ + (samplerVariablesOffs & ~0xD0600000)
        self.samplerVariables = [GX2SamplerVar(self.endianness) for _ in range(numSamplerVariables)]
        for samplerVariable in self.samplerVariables:
            samplerVariable.load(data, pos, pos_); pos += struct.calcsize(samplerVariable.format)

        pos = pos_ + (attribVariablesOffs & ~0xD0600000)
        self.attribVariables = [GX2AttribVar(self.endianness) for _ in range(numAttribVariables)]
        for attribVariable in self.attribVariables:
            attribVariable.load(data, pos, pos_); pos += struct.calcsize(attribVariable.format)

    def save(self):
        offset = 308

        uniformBlocksOffs = 0
        uniformVariablesOffs = 0
        loopVariablesOffs = 0
        samplerVariablesOffs = 0
        attribVariablesOffs = 0

        if self.uniformBlocks:
            uniformBlocksOffs = offset
            offset += len(self.uniformBlocks) * 3*4

        if self.uniformVariables:
            uniformVariablesOffs = offset
            offset += len(self.uniformVariables) * 5*4

        if align and self.loopVariables:
            loopVariablesOffs = offset
            offset += len(self.loopVariables) * 2*4

        if self.samplerVariables:
            samplerVariablesOffs = offset
            offset += len(self.samplerVariables) * 3*4

        if self.attribVariables:
            attribVariablesOffs = offset
            offset += len(self.attribVariables) * 4*4

        strTable = StringTable(offset)
        for uniformBlock in self.uniformBlocks:
            strTable.append(uniformBlock.name)

        for uniformVariable in self.uniformVariables:
            strTable.append(uniformVariable.name)

        for samplerVariable in self.samplerVariables:
            strTable.append(samplerVariable.name)

        for attribVariable in self.attribVariables:
            strTable.append(attribVariable.name)

        strTableB = strTable.save()
        offset += len(strTableB)

        if not align and self.loopVariables:
            loopVariablesOffs = offset
            offset += len(self.loopVariables) * 2*4

        if align:
            if uniformBlocksOffs: uniformBlocksOffs |= 0xD0600000
            if uniformVariablesOffs: uniformVariablesOffs |= 0xD0600000
            if loopVariablesOffs: loopVariablesOffs |= 0xD0600000
            if samplerVariablesOffs: samplerVariablesOffs |= 0xD0600000
            if attribVariablesOffs: attribVariablesOffs |= 0xD0600000

            uniformBlocks = b''.join([uniformBlock.save(strTable.getPos(uniformBlock.name) | 0xCA700000) for uniformBlock in self.uniformBlocks])
            uniformVariables = b''.join([uniformVariable.save(strTable.getPos(uniformVariable.name) | 0xCA700000) for uniformVariable in self.uniformVariables])
            loopVariables = b''.join([loopVariable.save() for loopVariable in self.loopVariables])
            samplerVariables = b''.join([samplerVariable.save(strTable.getPos(samplerVariable.name) | 0xCA700000) for samplerVariable in self.samplerVariables])
            attribVariables = b''.join([attribVariable.save(strTable.getPos(attribVariable.name) | 0xCA700000) for attribVariable in self.attribVariables])

            return b''.join([
                struct.pack(
                    '%s52I' % self.endianness, *self.regs,
                ),
                struct.pack(
                    '%s2I' % self.endianness, len(self.shader), 0,
                ),
                struct.pack(
                    '%s%s' % (self.endianness, self.format),
                    self.shaderMode,
                    len(self.uniformBlocks), uniformBlocksOffs,
                    len(self.uniformVariables), uniformVariablesOffs,
                    0, 0,
                    len(self.loopVariables), loopVariablesOffs,
                    len(self.samplerVariables), samplerVariablesOffs,
                    len(self.attribVariables), attribVariablesOffs,
                    self.ringItemSize,
                    int(self.hasStreamOut),
                ),
                struct.pack(
                    '%s4I' % self.endianness, *self.streamOutStride,
                ),
                self.shaderRBuffer.save(),
                uniformBlocks,
                uniformVariables,
                loopVariables,
                samplerVariables,
                attribVariables,
                strTableB,
            ])

        else:
            uniformBlocks = b''.join([uniformBlock.save(strTable.getPos(uniformBlock.name)) for uniformBlock in self.uniformBlocks])
            uniformVariables = b''.join([uniformVariable.save(strTable.getPos(uniformVariable.name)) for uniformVariable in self.uniformVariables])
            loopVariables = b''.join([loopVariable.save() for loopVariable in self.loopVariables])
            samplerVariables = b''.join([samplerVariable.save(strTable.getPos(samplerVariable.name)) for samplerVariable in self.samplerVariables])
            attribVariables = b''.join([attribVariable.save(strTable.getPos(attribVariable.name)) for attribVariable in self.attribVariables])

            return b''.join([
                struct.pack(
                    '%s52I' % self.endianness, *self.regs,
                ),
                struct.pack(
                    '%s2I' % self.endianness, len(self.shader), 0,
                ),
                struct.pack(
                    '%s%s' % (self.endianness, self.format),
                    self.shaderMode,
                    len(self.uniformBlocks), uniformBlocksOffs,
                    len(self.uniformVariables), uniformVariablesOffs,
                    0, 0,
                    len(self.loopVariables), loopVariablesOffs,
                    len(self.samplerVariables), samplerVariablesOffs,
                    len(self.attribVariables), attribVariablesOffs,
                    self.ringItemSize,
                    int(self.hasStreamOut),
                ),
                struct.pack(
                    '%s4I' % self.endianness, *self.streamOutStride,
                ),
                self.shaderRBuffer.save(),
                uniformBlocks,
                uniformVariables,
                samplerVariables,
                attribVariables,
                strTableB,
                loopVariables,
            ])


class GX2PixelShader:
    def __init__(self, endianness='>'):
        self.format = '11I'
        self.endianness = endianness

        global align
        align = True if endianness == '>' else False

        self.shaderMode = 1
        self.shaderRBuffer = None

        self.regs = []
        self.shader = b''
        self.uniformBlocks = []
        self.uniformVariables = []
        self.loopVariables = []
        self.samplerVariables = []

    def getShaderSizeAndOffset(self, data, pos):
        return struct.unpack_from('%s2I' % self.endianness, data, pos + 164)

    def getRegsLength(self):
        return 164

    def load(self, data, pos, shader):
        pos_ = pos

        self.shader = shader
        self.regs = struct.unpack_from('%s41I' % self.endianness, data, pos)

        pos += 164  # regs size
        pos += 8    # shaderSize and shaderOffs

        (self.shaderMode,
         numUniformBlocks, uniformBlocksOffs,
         numUniformVariables, uniformVariablesOffs,
         numInitialValues, initialValuesOffs,
         numLoopVariables, loopVariablesOffs,
         numSamplerVariables, samplerVariablesOffs) = struct.unpack_from('%s%s' % (self.endianness, self.format), data, pos)

        if numInitialValues: raise NotImplementedError("Initial values reading/saving is not implemented!")
        assert initialValuesOffs == 0

        pos += struct.calcsize(self.format)

        self.shaderRBuffer = GX2RBuffer(self.endianness)
        self.shaderRBuffer.load(data, pos)

        pos = pos_ + (uniformBlocksOffs & ~0xD0600000)
        self.uniformBlocks = [GX2UniformBlock(self.endianness) for _ in range(numUniformBlocks)]
        for uniformBlock in self.uniformBlocks:
            uniformBlock.load(data, pos, pos_); pos += struct.calcsize(uniformBlock.format)

        pos = pos_ + (uniformVariablesOffs & ~0xD0600000)
        self.uniformVariables = [GX2UniformVar(self.endianness) for _ in range(numUniformVariables)]
        for uniformVariable in self.uniformVariables:
            uniformVariable.load(data, pos, pos_); pos += struct.calcsize(uniformVariable.format)

        pos = pos_ + (loopVariablesOffs & ~0xD0600000)
        self.loopVariables = [GFDLoopVar(self.endianness) for _ in range(numLoopVariables)]
        for loopVariable in self.loopVariables:
            loopVariable.load(data, pos); pos += struct.calcsize(loopVariable.format)

        pos = pos_ + (samplerVariablesOffs & ~0xD0600000)
        self.samplerVariables = [GX2SamplerVar(self.endianness) for _ in range(numSamplerVariables)]
        for samplerVariable in self.samplerVariables:
            samplerVariable.load(data, pos, pos_); pos += struct.calcsize(samplerVariable.format)

    def save(self):
        offset = 232

        uniformBlocksOffs = 0
        uniformVariablesOffs = 0
        loopVariablesOffs = 0
        samplerVariablesOffs = 0

        if self.uniformBlocks:
            uniformBlocksOffs = offset
            offset += len(self.uniformBlocks) * 3*4

        if self.uniformVariables:
            uniformVariablesOffs = offset
            offset += len(self.uniformVariables) * 5*4

        if align and self.loopVariables:
            loopVariablesOffs = offset
            offset += len(self.loopVariables) * 2*4

        if self.samplerVariables:
            samplerVariablesOffs = offset
            offset += len(self.samplerVariables) * 3*4

        strTable = StringTable(offset)
        for uniformBlock in self.uniformBlocks:
            strTable.append(uniformBlock.name)

        for uniformVariable in self.uniformVariables:
            strTable.append(uniformVariable.name)

        for samplerVariable in self.samplerVariables:
            strTable.append(samplerVariable.name)

        strTableB = strTable.save()
        offset += len(strTableB)

        if not align and self.loopVariables:
            loopVariablesOffs = offset
            offset += len(self.loopVariables) * 2*4

        if align:
            if uniformBlocksOffs: uniformBlocksOffs |= 0xD0600000
            if uniformVariablesOffs: uniformVariablesOffs |= 0xD0600000
            if loopVariablesOffs: loopVariablesOffs |= 0xD0600000
            if samplerVariablesOffs: samplerVariablesOffs |= 0xD0600000

            uniformBlocks = b''.join([uniformBlock.save(strTable.getPos(uniformBlock.name) | 0xCA700000) for uniformBlock in self.uniformBlocks])
            uniformVariables = b''.join([uniformVariable.save(strTable.getPos(uniformVariable.name) | 0xCA700000) for uniformVariable in self.uniformVariables])
            loopVariables = b''.join([loopVariable.save() for loopVariable in self.loopVariables])
            samplerVariables = b''.join([samplerVariable.save(strTable.getPos(samplerVariable.name) | 0xCA700000) for samplerVariable in self.samplerVariables])

            return b''.join([
                struct.pack(
                    '%s41I' % self.endianness, *self.regs,
                ),
                struct.pack(
                    '%s2I' % self.endianness, len(self.shader), 0,
                ),
                struct.pack(
                    '%s%s' % (self.endianness, self.format),
                    self.shaderMode,
                    len(self.uniformBlocks), uniformBlocksOffs,
                    len(self.uniformVariables), uniformVariablesOffs,
                    0, 0,
                    len(self.loopVariables), loopVariablesOffs,
                    len(self.samplerVariables), samplerVariablesOffs,
                ),
                self.shaderRBuffer.save(),
                uniformBlocks,
                uniformVariables,
                loopVariables,
                samplerVariables,
                strTableB,
            ])

        else:
            uniformBlocks = b''.join([uniformBlock.save(strTable.getPos(uniformBlock.name)) for uniformBlock in self.uniformBlocks])
            uniformVariables = b''.join([uniformVariable.save(strTable.getPos(uniformVariable.name)) for uniformVariable in self.uniformVariables])
            loopVariables = b''.join([loopVariable.save() for loopVariable in self.loopVariables])
            samplerVariables = b''.join([samplerVariable.save(strTable.getPos(samplerVariable.name)) for samplerVariable in self.samplerVariables])

            return b''.join([
                struct.pack(
                    '%s41I' % self.endianness, *self.regs,
                ),
                struct.pack(
                    '%s2I' % self.endianness, len(self.shader), 0,
                ),
                struct.pack(
                    '%s%s' % (self.endianness, self.format),
                    self.shaderMode,
                    len(self.uniformBlocks), uniformBlocksOffs,
                    len(self.uniformVariables), uniformVariablesOffs,
                    0, 0,
                    len(self.loopVariables), loopVariablesOffs,
                    len(self.samplerVariables), samplerVariablesOffs,
                ),
                self.shaderRBuffer.save(),
                uniformBlocks,
                uniformVariables,
                samplerVariables,
                strTableB,
                loopVariables,
            ])
