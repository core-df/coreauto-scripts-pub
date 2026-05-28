# Copyright Core DF — Apache License 2.0
JsonParse <- function(text) tryCatch(list(status_code=200L, data=jsonlite::fromJSON(text, simplifyVector=FALSE)), error=function(e) list(status_code=400L, error=e$message))
JsonStringify <- function(data, indent=NULL) tryCatch({ t<-jsonlite::toJSON(data, auto_unbox=TRUE, pretty=isTRUE(indent>0)); list(status_code=200L, text=t)}, error=function(e) list(status_code=400L, error=e$message))
CsvToRows <- function(text, delimiter=",") {
  con <- textConnection(text); on.exit(close(con))
  rows <- tryCatch(as.data.frame(read.csv(con, sep=delimiter, stringsAsFactors=FALSE)), error=function(e) NULL)
  if (is.null(rows)) return(list(status_code=400L, error="csv error"))
  list(status_code=200L, rows=lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop=FALSE])))
}
RowsToCsv <- function(rows, delimiter=",") {
  if (length(rows)==0) return(list(status_code=400L, error="rows must not be empty"))
  df <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors=FALSE))
  list(status_code=200L, text=paste(capture.output(write.csv(df, row.names=FALSE, sep=delimiter)), collapse="\n"))
}
XmlToDict <- function(text) {
  tag <- sub("^.*<([A-Za-z0-9_:-]+).*", "\\1", text)
  if (!nzchar(tag) || tag == text) return(list(status_code=400L, error="xml parse error"))
  list(status_code=200L, data=setNames(list(list()), tag))
}
DictToXml <- function(data, root_tag="root") tryCatch(list(status_code=200L, text=paste0("<",root_tag,"/>")), error=function(e) list(status_code=400L, error=e$message))
