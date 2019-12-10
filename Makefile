.PHONY: all clean

SIGN 	= ldid2
TARGET 	= serialsh
IGCC 	?= xcrun -sdk iphoneos cc
FLAGS 	?= -O2 -framework Foundation
ARCH 	?= -arch arm64 -arch armv7 -arch armv7s

default: $(TARGET)

$(TARGET): $(TARGET).m
	@echo "[INFO]: compiling $(TARGET)"
	@echo "CC 	$(TARGET)"
	@$(IGCC) $(ARCH) -o $@ $(FLAGS) $^
	@$(SIGN) -S $(TARGET)
	@echo "OK: compiled $(TARGET)"

clean:
	rm -f $(TARGET)