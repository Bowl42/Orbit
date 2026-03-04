APP   = ring.app
BIN   = .build/release/ring
MACOS = $(APP)/Contents/MacOS

.PHONY: build run clean

build:
	swift build -c release
	mkdir -p $(MACOS)
	cp $(BIN) $(MACOS)/ring
	cp Info.plist $(APP)/Contents/Info.plist
	codesign --force --deep --sign - $(APP)

run: build
	open $(APP)

clean:
	rm -rf $(APP)
	swift package clean
