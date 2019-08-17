.PHONY: all clean

SIGN 	= ldid
TARGET 	= serialsh
IGCC 	?= xcrun -sdk iphoneos cc
FLAGS 	?= -O2 -framework Foundation
ARCH 	?= -arch arm64 -arch armv7 -arch armv7s
# by default i don't add arm64e support, do it yourself.

all: $(TARGET)

$(TARGET): $(TARGET).m
		@echo "[INFO]: compiling $(TARGET)"
		$(IGCC) $(ARCH) -o $@ $(FLAGS) $^
		$(SIGN) -S $(TARGET)
		@echo "OK: compiled $(TARGET)"

clean:
		rm -f $(TARGET)