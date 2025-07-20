all: encode decode

encode: encode.asm
	./nasm.exe -f win32 encode.asm
	./nlink.exe --enable-stdcall-fixup encode.obj kernel32.dll -lio -o encode.exe

decode: decode.asm
	./nasm.exe -f win32 decode.asm
	./nlink.exe --enable-stdcall-fixup decode.obj kernel32.dll -lio -o decode.exe

compress: encode
	./encode.exe

decompress: decode
	./decode.exe

clean:
	rm encode.obj encode.exe decode.obj decode.exe compressed compressed.debug