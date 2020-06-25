#!/usr/bin/python3
import sys
import binascii
import applicationConfiguration_pb2

f = open("export.bin", "rb")
g = applicationConfiguration_pb2.ApplicationConfiguration()
#header = f.read(16)
#print("header:"+str(header))
g.ParseFromString(f.read())
f.close()
print(g)

