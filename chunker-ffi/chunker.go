package main

import "C"
import (
	"io"
	"os"
	"unsafe"

	"github.com/restic/chunker"
)

// Polynomial value used by dejavu
const polynomial = chunker.Pol(0x3DA3358B4DC173)

// ChunkerHandle represents an opaque chunker instance
type ChunkerHandle struct {
	file    *os.File
	chunker *chunker.Chunker
}

var chunkers = make(map[int]*ChunkerHandle)
var nextID = 1

//export ChunkerNew
// Creates a new chunker for the given file path
// Returns handle ID (>0) on success, or 0 on error
func ChunkerNew(filePath *C.char) C.int {
	goPath := C.GoString(filePath)
	
	file, err := os.Open(goPath)
	if err != nil {
		return 0
	}

	chnkr := chunker.NewWithBoundaries(file, polynomial, chunker.MinSize, chunker.MaxSize)
	
	handle := &ChunkerHandle{
		file:    file,
		chunker: chnkr,
	}
	
	id := nextID
	chunkers[id] = handle
	nextID++
	
	return C.int(id)
}

//export ChunkerNext
// Gets the next chunk from the chunker
// Returns chunk size (>0) on success, 0 on EOF, -1 on error
// The chunk data is copied to the provided buffer
func ChunkerNext(handle C.int, buffer *C.char, bufferSize C.int) C.int {
	chnkrHandle, ok := chunkers[int(handle)]
	if !ok {
		return -1
	}

	buf := make([]byte, chunker.MaxSize)
	chunk, err := chnkrHandle.chunker.Next(buf)
	
	if err == io.EOF {
		return 0
	}
	
	if err != nil {
		return -1
	}

	// Copy chunk data to the provided buffer
	chunkSize := len(chunk.Data)
	if chunkSize > int(bufferSize) {
		return -1 // Buffer too small
	}

	// Use unsafe to copy data
	dst := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), chunkSize)
	copy(dst, chunk.Data)
	
	return C.int(chunkSize)
}

//export ChunkerClose
// Closes the chunker and frees resources
func ChunkerClose(handle C.int) {
	chnkrHandle, ok := chunkers[int(handle)]
	if ok {
		chnkrHandle.file.Close()
		delete(chunkers, int(handle))
	}
}

//export ChunkerGetMinSize
// Returns the minimum chunk size
func ChunkerGetMinSize() C.int {
	return C.int(chunker.MinSize)
}

//export ChunkerGetMaxSize
// Returns the maximum chunk size
func ChunkerGetMaxSize() C.int {
	return C.int(chunker.MaxSize)
}

func main() {
	// Required for building as shared library
}

