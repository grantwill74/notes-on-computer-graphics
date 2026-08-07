PDF_STANDARD=ua-1

all: */*.pdf

%.pdf: %.typ
	typst compile --pdf-standard $(PDF_STANDARD) --root=".." $<

