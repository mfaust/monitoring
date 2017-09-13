package main

type Message struct {
    Host string `json:"host"`
    Ports []int  `json:"ports"`
}
