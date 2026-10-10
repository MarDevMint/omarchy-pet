.pragma library

// file:///path URL (e.g. from Qt.resolvedUrl) -> plain local path.
function localPath(url) {
  return decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
}
