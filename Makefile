APP       = ring.app
BIN       = .build/release/ring
MACOS     = $(APP)/Contents/MacOS
RESOURCES = $(APP)/Contents/Resources

.PHONY: build run clean

build:
	swift build -c release
	mkdir -p $(MACOS) $(RESOURCES)
	cp $(BIN) $(MACOS)/ring
	cp Info.plist $(APP)/Contents/Info.plist
	cp ring.icns $(RESOURCES)/ring.icns
	codesign --force --deep --sign - $(APP)

run: build
	open $(APP)

clean:
	rm -rf $(APP)
	swift package clean
