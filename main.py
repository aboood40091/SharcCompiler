#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from io import StringIO
import os
import subprocess
import sys

import sharc

import sharcfb
gsh = sharcfb.gsh
gx2shader = sharcfb.gx2shader


# Modify this
gshCompilePath = r'D:\cafe_sdk-2_13_01\system\bin\win64\gshCompile.exe'


compileCmd = '''"{}"
-p "%s"
-v "%s"
-o "%s"
-no_limit_array_syms
-nospark'''.replace('\n', ' ').format(gshCompilePath)

compileCmdHeader = '''"{}"
-p "%s"
-v "%s"
-oh "%s"
-no_limit_array_syms
-nospark'''.replace('\n', ' ').format(gshCompilePath)


def verifyGshCompile():
    temp_gshCompilePath = gshCompilePath
    if not temp_gshCompilePath.endswith('.exe'):
        temp_gshCompilePath += '.exe'

    if not os.path.isfile(temp_gshCompilePath):
        print("'gshCompilePath' not set properly!")
        print("Modify this script and set 'gshCompilePath' to the path to gshCompile.exe")
        sys.exit(1)


def printInfo():
    print('\nUsage:')
    print('py -3 main.py <input>.sharc')
    print('or:')
    print('python3 main.py <input>.sharc')
    sys.exit(1)


def main():
    verifyGshCompile()

    print('SharcCompiler v0.1')
    print('(C) 2019 AboodXD')
    print('Only tested for NSMBU!')

    if len(sys.argv) < 2:
        printInfo()

    filename = os.path.realpath(sys.argv[1])
    path = os.path.dirname(filename)

    if not os.path.isfile(filename):
        printInfo()

    with open(filename, 'rb') as inf:
        inb = inf.read()

    progList, codeList = sharc.load(inb)
    fbBinaryList, fbProgList = sharcfb.List(), sharcfb.List()

    fbHeader = sharcfb.Header()
    fbHeader.name = sharc.header.name

    for i, program in enumerate(progList):
        assert -1 not in (program.vtxShIdx, program.frgShIdx) and program.geoShIdx == -1

        print('\nProcessing program: %s' % program.name)
        fbProgram = sharcfb.ShaderProgram()
        fbProgram.name = program.name

        fbProgram.variations = program.variations
        fbProgram.variationSymbols = program.variationSymbols
        fbProgram.uniformVariables = program.uniformVariables
        fbProgram.uniformBlocks = program.uniformBlocks
        fbProgram.samplerVariables = program.samplerVariables
        fbProgram.attribVariables = program.attribVariables

        fbProgram.kind = 3
        fbProgram.baseIndex = i*2

        vtxSrc = codeList[program.vtxShIdx]
        frgSrc = codeList[program.frgShIdx]

        code = ''
        counter = 0
        with StringIO(vtxSrc.code) as vtxSrcS:
            for line in vtxSrcS:
                if line.startswith("#define"):
                    s = line.split(); index = program.vertexMacros.index(s[1])
                    if index != -1:
                        #print(s[1], program.vertexMacros[index].value)
                        line = '#define %s %s\n' % (s[1], program.vertexMacros[index].value)
                        counter += 1

                code += line

        print('Overriden %d macros in the vertex shader' % counter)
        vtxSrc.code = code

        code = ''
        counter = 0
        with StringIO(frgSrc.code) as frgSrcS:
            for line in frgSrcS:
                if line.startswith("#define"):
                    s = line.split(); index = program.fragmentMacros.index(s[1])
                    if index != -1:
                        #print(s[1], program.fragmentMacros[index].value)
                        line = '#define %s %s\n' % (s[1], program.fragmentMacros[index].value)
                        counter += 1

                code += line

        print('Overriden %d macros in the fragment shader' % counter)
        frgSrc.code = code

        shaderPath = os.path.join(path, program.name)

        if not os.path.isdir(shaderPath):
            os.mkdir(shaderPath)

        vtxSrc.export(shaderPath)
        frgSrc.export(shaderPath)

        vtxName = os.path.join(shaderPath, vtxSrc.name)
        frgName = os.path.join(shaderPath, frgSrc.name)
        gshName = os.path.join(shaderPath, 'out.gsh')
        hdrName = os.path.join(shaderPath, 'out.h')

        print('Compiling shaders...')
        print(compileCmd % (frgName, vtxName, gshName))
        subprocess.call(compileCmd % (frgName, vtxName, gshName))
        subprocess.call(compileCmdHeader % (frgName, vtxName, hdrName))
        assert os.path.isfile(gshName)
        assert os.path.isfile(hdrName)

        vtx, pix = gsh.getShaders(gshName)

        #os.remove(vtxName)
        #os.remove(frgName)
        #os.remove(gshName)

        gx2shader.align = False
        vtx.endianness = '<'
        pix.endianness = '<'

        vtx.shaderRBuffer.endianness = '<'
        pix.shaderRBuffer.endianness = '<'

        for uniformBlock in vtx.uniformBlocks:
            uniformBlock.endianness = '<'

        for uniformVariable in vtx.uniformVariables:
            uniformVariable.endianness = '<'

        for loopVariable in vtx.loopVariables:
            loopVariable.endianness = '<'

        for samplerVariable in vtx.samplerVariables:
            samplerVariable.endianness = '<'

        for attribVariable in vtx.attribVariables:
            attribVariable.endianness = '<'

        for uniformBlock in pix.uniformBlocks:
            uniformBlock.endianness = '<'

        for uniformVariable in pix.uniformVariables:
            uniformVariable.endianness = '<'

        for loopVariable in pix.loopVariables:
            loopVariable.endianness = '<'

        for samplerVariable in pix.samplerVariables:
            samplerVariable.endianness = '<'

        fbVtx = sharcfb.ShaderBinary()
        fbVtx.type = 0
        fbVtx.binary = vtx

        fbPix = sharcfb.ShaderBinary()
        fbPix.type = 1
        fbPix.binary = pix

        fbProgList.append(fbProgram)
        fbBinaryList.append(fbVtx)
        fbBinaryList.append(fbPix)

    with open(os.path.splitext(filename)[0] + '.sharcfb', 'wb') as out:
        out.write(sharcfb.save(fbHeader, fbBinaryList, fbProgList))

if __name__ == '__main__':
    main()
