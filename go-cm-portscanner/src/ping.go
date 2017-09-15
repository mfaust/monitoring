package main

import (
  "log"
  "os/exec"
  "strings"
)

func PingHost(host string) (bool) {

  cmd := exec.Command("ping", host, "-c 1", "-t 2")

  output, err := cmd.CombinedOutput()

  if err != nil {
    log.Printf("event='ping_cmd_error' name='%s' error='%s'\n", host, err)
  }

  if strings.Contains(string(output), "Destination Host Unreachable") {
    return false
  } else {
    return true
  }

}
