use time::{OffsetDateTime, UtcOffset};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UtcDay {
    pub year: i32,
    pub month: u8,
    pub day: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IsoWeek {
    pub year: i32,
    pub week: u8,
}

pub struct LocalClock;

impl LocalClock {
    pub fn now_local_hhmm() -> String {
        let now = OffsetDateTime::now_utc();

        let local_offset = UtcOffset::current_local_offset().unwrap_or(UtcOffset::UTC);
        let local_time = now.to_offset(local_offset);

        format!("{:02}{:02}", local_time.hour(), local_time.minute())
    }

    pub fn today_utc() -> UtcDay {
        let now = OffsetDateTime::now_utc();
        UtcDay {
            year: now.year(),
            month: now.month() as u8,
            day: now.day(),
        }
    }

    pub fn iso_week(utc: &UtcDay) -> IsoWeek {
        let date = time::Date::from_calendar_date(
            utc.year,
            time::Month::try_from(utc.month).unwrap(),
            utc.day,
        )
        .unwrap();

        let (year, week, _) = date.to_iso_week_date();
        IsoWeek { year, week }
    }
}

impl UtcDay {
    pub fn filename(&self) -> String {
        format!("{:04}-{:02}-{:02}.md", self.year, self.month, self.day)
    }
}
