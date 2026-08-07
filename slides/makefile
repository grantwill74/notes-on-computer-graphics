PDF_STANDARD=ua-1

%.pdf: %.typ
	typst compile --pdf-standard $(PDF_STANDARD) --root=".." $<

all: */*.pdf
