export PATH=/usr/local/bin:$PATH

export LC_CTYPE=C
export LANG=C

for FILE in {query}; do
argv="$FILE"

filename=`sed -e "s/.*\/\(.*\.pdf$\)/\1/"<<<"$argv"`
path=`sed -e "s/\(\/.*\)\/.*\.pdf$/\1/"<<<"$argv"`

cd "$path"

outname=`sed -e "s/\.pdf$/_.pdf/"<<<"$filename"`

pdftk "$filename" output - uncompress | sed '/^\/Annots/d' | pdftk - output "$outname" compress

finalname=`sed -e "s/\_\.pdf$/.pdf/"<<<"$outname"`
mv "$outname" "$exportPath"/"$finalname"

done

if [ "$openFolder" == "1" ]; then
	open "$exportPath"
fi