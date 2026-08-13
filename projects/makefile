all: */project.html

%.html: %.typ
	typst compile --format=html --features html $< $@
	
