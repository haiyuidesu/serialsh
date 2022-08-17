.PHONY: all clean

SIGN 	= ldid2
TARGET 	= serialsh
IGCC 	?= xcrun -sdk iphoneos gcc
FLAGS 	?= -O2 -framework Foundation -miphoneos-version-min=6.0
ARCH 	?= -arch arm64 -arch armv7 -arch armv7s

default: $(TARGET)

$(TARGET): $(TARGET).m
	@echo "[INFO]: compiling $(TARGET)"
	@echo "CC 	$(TARGET)"
	@$(IGCC) $(ARCH) -o $@ $(FLAGS) $^
	@$(SIGN) -S $(TARGET)
	@echo "OK: compiled $(TARGET)"

clean:
	@echo "removed $(TARGET)"
	@rm -f $(TARGET)
