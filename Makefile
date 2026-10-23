# Golf: The Empire. Run these from the project folder in Terminal.

.PHONY: assets project test data preview

# Regenerate every asset by manifest id (placeholders until the real generators land).
assets:
	python3 art/audio.py
	python3 art/placeholders.py

# Regenerate the Xcode project from project.yml (needs: brew install xcodegen).
project:
	xcodegen generate

# Run the GameCore rules tests headless.
test:
	cd Packages/GameCore && swift test -c release -Xswiftc -enable-testing

# Re-extract plots, towns, names and Percy's lines from the prototype.
data:
	node tools/extract-prototype-data.mjs

# Render hero holes and the golfer rig to art-preview-output/index.html (open it in Safari).
preview:
	cd Packages/GameCore && swift run -c release art-preview ../../art-preview-output
