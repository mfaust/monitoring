package main

import (
  "fmt"
  "net/http"
  "encoding/json"

  "github.com/gorilla/mux"
)

func Index(w http.ResponseWriter, r *http.Request) {
  fmt.Fprintln(w, "Welcome!")
  fmt.Fprintln(w, "this is a simple port scanner for CoreMedia Applications")
}

func ScanHost(w http.ResponseWriter, r *http.Request) {
  vars := mux.Vars(r)
  host_name := vars["host"]

  var ports []int

  if PingHost( host_name ) == true {

    ports = scan_port( host_name )
  }

  w.Header().Set("Content-Type", "application/json; charset=UTF-8")

  m := Message{ host_name, ports }

  if err := json.NewEncoder(w).Encode(m); err != nil {
    panic(err)
  }
}
