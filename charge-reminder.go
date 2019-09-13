package main

import (
    "fmt"
    "log"
    "os"
    "os/exec"
    "strconv"
    "strings"
    "time"

    "github.com/0xAX/notificator"
)

/* 
  Periodically checks the current battery level and alerts the
  user if it is low (and not charging).

  Run as:

      go get github.com/0xAX/notificator
      go run charge-reminder.go

  Or compile with

      go get github.com/0xAX/notificator
      go build charge-reminder.go

  and put the binary somewhere on the PATH.
*/ 

var checkInterval = 5 * time.Second

var chargeLevelA = 30
var notificationBackoffA = 120 * time.Second
var chargeLevelB = 10
var notificationBackoffB = 60 * time.Second
var chargeLevelC = 5
var notificationBackoffC = 10 * time.Second
// TODO: make nicer

// // // // // // // // // // // // // // // 

var logger *log.Logger
var notify *notificator.Notificator

func check(err error) {
    if err != nil {
        panic(err)
    }
}

func GetPowerDevice(pattern string) string {
    cmd := fmt.Sprintf("upower -e | grep %s | head -n 1", pattern)
    out, err := exec.Command("bash", "-c", cmd).Output(); check(err)
    return strings.TrimSpace(string(out))
}

func IsLinePowerOnline(device string) bool {
    cmd := fmt.Sprintf("upower -i %s | grep online", device)
    out, err := exec.Command("bash", "-c", cmd).Output(); check(err)
    return strings.Contains(string(out), "yes")
}

func GetChargingLevel(device string) int {
    cmd := fmt.Sprintf("upower -i %s | grep percentage | sed 's/[^0-9]//g'", device)
    out, err := exec.Command("bash", "-c", cmd).Output(); check(err)
    chargeString := strings.TrimSpace(string(out))
    charge, err := strconv.Atoi(chargeString); check(err)
    return charge
}

var lastNotification time.Time

func Notify(message string, level string, frequency time.Duration) {
    if time.Now().Sub(lastNotification) > frequency {
        notify.Push("Charge Reminder", message, "", level)
        lastNotification = time.Now()
    }
}

var lineDevice string
var batteryDevice string

func CheckCharge() {
    if IsLinePowerOnline(lineDevice) {
        logger.Print("AC connected")
        return
    }
    logger.Print("AC disconnected")
    
    charge := GetChargingLevel(batteryDevice)
    logger.Printf("Battery at %d%%\n", charge)
    
    switch {
    case charge <= chargeLevelC:
        Notify(fmt.Sprintf("BATTERY AT %d%% -- HELP!!", charge),
            notificator.UR_CRITICAL,
            notificationBackoffC)
    case charge <= chargeLevelB:
        Notify(fmt.Sprintf("Battery at %d%% -- plug in!", charge), 
            notificator.UR_NORMAL,
            notificationBackoffB)
    case charge <= chargeLevelA:
        Notify(fmt.Sprintf("Battery at %d%% -- forgot to plug in?", charge), 
            notificator.UR_NORMAL, 
            notificationBackoffA)
    }
}

func main() {
    notify = notificator.New(notificator.Options { AppName: "Charge Reminder" })
    logger = log.New(os.Stdout, "[Charge Reminder] ", log.LstdFlags)

    lineDevice = GetPowerDevice("line")
    batteryDevice = GetPowerDevice("battery")

    for {
        CheckCharge()
        time.Sleep(checkInterval)
    }
}
