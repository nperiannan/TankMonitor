#include "Scheduler.h"
#include "Logger.h"
#include "Globals.h"
#include "MotorControl.h"
#include "Config.h"
#include <Preferences.h>
#include <time.h>

Schedule schedules[MAX_SCHEDULES];

static unsigned long lastScheduleCheck = 0;

// -----------------------------------------------------------------------
//  NVS helpers
// -----------------------------------------------------------------------

void initScheduler() {
    Preferences prefs;
    prefs.begin("scheduler", true);
    for (int i = 0; i < MAX_SCHEDULES; i++) {
        String prefix = String(i) + "_";
        schedules[i].enabled   = prefs.getBool  ((prefix + "en").c_str(),   false);
        schedules[i].motorType = prefs.getUChar  ((prefix + "mt").c_str(),   0);   // 0=OH, 1=UG
        schedules[i].time      = prefs.getString ((prefix + "t").c_str(),    "00:00");
        schedules[i].duration  = prefs.getUShort ((prefix + "d").c_str(),    2);
        schedules[i].isRunning = false;
        schedules[i].startTime = 0;
    }
    prefs.end();
    Log(INFO, "[Sched] Loaded " + String(MAX_SCHEDULES) + " schedules");
}

void saveSchedules() {
    Preferences prefs;
    prefs.begin("scheduler", false);
    for (int i = 0; i < MAX_SCHEDULES; i++) {
        String prefix = String(i) + "_";
        prefs.putBool  ((prefix + "en").c_str(),  schedules[i].enabled);
        prefs.putUChar ((prefix + "mt").c_str(),  schedules[i].motorType);
        prefs.putString((prefix + "t").c_str(),   schedules[i].time);
        prefs.putUShort((prefix + "d").c_str(),   schedules[i].duration);
    }
    prefs.end();
    Log(INFO, "[Sched] Saved");
}

void clearAllSchedules() {
    for (int i = 0; i < MAX_SCHEDULES; i++) {
        schedules[i] = {false, 0, "00:00", 2, false, 0};
    }
    saveSchedules();
    Log(INFO, "[Sched] All cleared");
}

// -----------------------------------------------------------------------
//  Runtime check – call from loop()
// -----------------------------------------------------------------------

void checkSchedules() {
    if (millis() < BOOT_GRACE_PERIOD_MS) return;   // suppress scheduler during boot
    if (millis() - lastScheduleCheck < 10000UL) return;
    lastScheduleCheck = millis();

    struct tm ti;
    if (!getLocalTime(&ti)) return;

    char nowBuf[6];
    snprintf(nowBuf, sizeof(nowBuf), "%02d:%02d", ti.tm_hour, ti.tm_min);
    String nowStr = String(nowBuf);

    for (int i = 0; i < MAX_SCHEDULES; i++) {
        Schedule& s = schedules[i];
        bool isUG = (s.motorType == 1);

        // Disabled but was running – stop
        if (!s.enabled) {
            if (s.isRunning) {
                s.isRunning = false;
                bool anyRunning = false;
                for (int j = 0; j < MAX_SCHEDULES; j++) {
                    if (schedules[j].isRunning && schedules[j].motorType == s.motorType) {
                        anyRunning = true; break;
                    }
                }
                if (!anyRunning) {
                    if (isUG) turnOffUGMotor(); else turnOffOHMotor();
                    Log(INFO, "[Sched] " + String(i) + " stopped (disabled)");
                }
            }
            continue;
        }

        // Start trigger
        if (!s.isRunning && nowStr == s.time) {
            Log(INFO, "[Sched] " + String(i) + " (" + (isUG?"UG":"OH") + ") starting at " + s.time
                + " for " + String(s.duration) + " min");
            if (isUG) turnOnUGMotor(); else turnOnOHMotor();
            s.isRunning = true;
            s.startTime = millis();
        }

        // Stop trigger: duration expired
        if (s.isRunning) {
            unsigned long elapsed = millis() - s.startTime;
            if (elapsed >= (unsigned long)s.duration * 60000UL) {
                s.isRunning = false;
                Log(INFO, "[Sched] " + String(i) + " (" + (isUG?"UG":"OH") + ") finished after "
                    + String(s.duration) + " min");
                bool anyRunning = false;
                for (int j = 0; j < MAX_SCHEDULES; j++) {
                    if (schedules[j].isRunning && schedules[j].motorType == s.motorType) {
                        anyRunning = true; break;
                    }
                }
                if (!anyRunning) {
                    if (isUG) turnOffUGMotor(); else turnOffOHMotor();
                }
            }
        }
    }
}
