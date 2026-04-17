#!/usr/bin/dotnet

using System.Globalization;

if (!TryParseArguments(args, out var inputPath, out var selectedDate, out var argumentError))
{
	Console.Error.WriteLine(argumentError);
	Console.Error.WriteLine("Usage: timecard.cs -f <events-file> [-d yyyy-MM-dd]");
	return 1;
}

inputPath = Path.GetFullPath(inputPath);
if (!File.Exists(inputPath))
{
	Console.Error.WriteLine($"File not found: {inputPath}");
	return 1;
}

IReadOnlyList<EventEntry> events;
try
{
	events = ParseEvents(inputPath);
}
catch (FormatException exception)
{
	Console.Error.WriteLine(exception.Message);
	return 1;
}
const string Work = "work";
const string Personal = "personal";
const string Startup = "startup";
const string Shutdown = "shutdown";
const string Offline = "personal (offline)";

var reportEnd = DateTimeOffset.Now;
var blocks = BuildBlocks(events, reportEnd);
PrintReport(blocks, selectedDate);
return 0;

bool TryParseArguments(string[] values, out string filePath, out DateOnly? date, out string? error)
{
	filePath = string.Empty;
	date = null;
	error = null;

	for (var index = 0; index < values.Length; index++)
	{
		var argument = values[index];
		switch (argument)
		{
			case "-f":
			case "--file":
				if (!TryReadValue(values, ref index, argument, out var parsedFilePath, out error))
				{
					return false;
				}

				filePath = parsedFilePath;
				break;

			case "-d":
			case "--date":
				if (!TryReadValue(values, ref index, argument, out var parsedDate, out error))
				{
					return false;
				}

				if (!DateOnly.TryParseExact(parsedDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var selectedDate))
				{
					error = $"Invalid date: '{parsedDate}'. Expected format: yyyy-MM-dd";
					return false;
				}

				date = selectedDate;
				break;

			default:
				error = $"Unknown argument: {argument}";
				return false;
		}
	}

	if (string.IsNullOrWhiteSpace(filePath))
	{
		error = "Missing required file argument: -f or --file";
		return false;
	}

	return true;
}

bool TryReadValue(string[] values, ref int index, string argumentName, out string value, out string? error)
{
	value = string.Empty;
	error = null;

	var nextIndex = index + 1;
	if (nextIndex >= values.Length)
	{
		error = $"Missing value for {argumentName}";
		return false;
	}

	value = values[nextIndex];
	index = nextIndex;
	return true;
}

IReadOnlyList<EventEntry> ParseEvents(string path)
{
	var events = new List<EventEntry>();
	var lineNumber = 0;

	foreach (var rawLine in File.ReadLines(path))
	{
		lineNumber++;
		var line = rawLine.Trim();
		if (string.IsNullOrWhiteSpace(line))
		{
			continue;
		}


		var parts = line.Split(';', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
		if (parts.Length != 2)
		{
			throw new FormatException($"Invalid format at line {lineNumber}: expected '<unix-timestamp>;<event>'");
		}

		if (!long.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var unixSeconds))
		{
			throw new FormatException($"Invalid unix timestamp at line {lineNumber}: '{parts[0]}'");
		}

		var kind = NormalizeKind(parts[1], lineNumber);
		events.Add(new EventEntry(DateTimeOffset.FromUnixTimeSeconds(unixSeconds), kind, lineNumber));
	}

	return events
		.OrderBy(static entry => entry.Timestamp)
		.ThenBy(static entry => entry.LineNumber)
		.ToList();
}

string NormalizeKind(string rawKind, int lineNumber)
{
	var kind = rawKind.Trim().ToLowerInvariant();
	return kind switch
	{
		Work => Work,
		Personal => Personal,
		Startup => Startup,
		Shutdown => Shutdown,
		_ => throw new FormatException($"Invalid event at line {lineNumber}: '{rawKind}'. Allowed values: work, personal, startup, shutdown")
	};
}

IReadOnlyList<TimeBlock> BuildBlocks(IReadOnlyList<EventEntry> events, DateTimeOffset reportEnd)
{
	var blocks = new List<TimeBlock>();
	string? activeState = null;
	DateTimeOffset? activeSince = null;
	DateTimeOffset? offlineSince = null;

	foreach (var entry in events)
	{
		switch (entry.Kind)
		{
			case Work:
			case Personal:
				AddStateBlock(blocks, activeState, activeSince, entry.Timestamp);
				activeState = entry.Kind;
				activeSince = entry.Timestamp;
				break;

			case Shutdown:
				AddStateBlock(blocks, activeState, activeSince, entry.Timestamp);
				activeState = null;
				activeSince = null;
				offlineSince = entry.Timestamp;
				break;

			case Startup:
				if (offlineSince is not null)
				{
					AddSplitBlocks(blocks, Offline, offlineSince.Value, entry.Timestamp);
					offlineSince = null;
				}

				break;
		}
	}

	if (activeState is not null && activeSince is not null)
	{
		AddStateBlock(blocks, activeState, activeSince, reportEnd, isOngoing: true);
	}
	else if (offlineSince is not null)
	{
		AddSplitBlocks(blocks, Offline, offlineSince.Value, reportEnd, isOngoing: true);
	}

	return blocks;
}

void AddStateBlock(List<TimeBlock> blocks, string? state, DateTimeOffset? start, DateTimeOffset end, bool isOngoing = false)
{
	if (state is null || start is null)
	{
		return;
	}

	AddSplitBlocks(blocks, state, start.Value, end, isOngoing);
}

void AddSplitBlocks(List<TimeBlock> blocks, string category, DateTimeOffset start, DateTimeOffset end, bool isOngoing = false)
{
	if (end <= start)
	{
		return;
	}

	var cursor = start;
	while (cursor < end)
	{
		var local = cursor.ToLocalTime();
		var nextMidnightDate = DateTime.SpecifyKind(local.Date.AddDays(1), DateTimeKind.Unspecified);
		var nextMidnightLocal = new DateTimeOffset(nextMidnightDate, TimeZoneInfo.Local.GetUtcOffset(nextMidnightDate));
		var segmentEnd = nextMidnightLocal.ToUniversalTime() < end ? nextMidnightLocal.ToUniversalTime() : end;

		blocks.Add(new TimeBlock(category, cursor, segmentEnd, IsOngoing: isOngoing && segmentEnd == end));
		cursor = segmentEnd;
	}
}

void PrintReport(IReadOnlyList<TimeBlock> blocks, DateOnly? selectedDate)
{
	const string Work = "work";
	const string Personal = "personal";
	const int LabelWidth = 18;
	const int DurationWidth = 8;
	const int TimeWidth = 8;
	const int CategoryWidth = 18;
	const int StatusWidth = 7;

	var visibleBlocks = blocks
		.Where(static block => block.Category is Work or Personal)
		.ToList();

	var days = visibleBlocks
		.GroupBy(static block => block.Start.ToLocalTime().Date)
		.Where(group => selectedDate is null || DateOnly.FromDateTime(group.Key) == selectedDate.Value)
		.OrderBy(static group => group.Key)
		.ToList();

	foreach (var day in days)
	{
		var work = day.Where(static block => block.Category == Work).Aggregate(TimeSpan.Zero, static (sum, block) => sum + block.Duration);
		var personal = day.Where(static block => block.Category == Personal).Aggregate(TimeSpan.Zero, static (sum, block) => sum + block.Duration);

		Console.WriteLine(day.Key.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
		Console.WriteLine($"  {Work,-LabelWidth} {FormatDuration(work),DurationWidth}");
		Console.WriteLine($"  {Personal,-LabelWidth} {FormatDuration(personal),DurationWidth}");
		Console.WriteLine("  blocks:");
		Console.WriteLine($"    {"start",-TimeWidth} {"end",-TimeWidth} {"category",-CategoryWidth} {"duration",DurationWidth} {"status",-StatusWidth}");

		foreach (var block in day.OrderBy(static block => block.Start))
		{
			var start = block.Start.ToLocalTime();
			var end = block.End.ToLocalTime();
			var startText = start.ToString("HH:mm:ss", CultureInfo.InvariantCulture);
			var endText = end.ToString("HH:mm:ss", CultureInfo.InvariantCulture);
			var status = block.IsOngoing ? "ongoing" : string.Empty;
			Console.WriteLine($"    {startText,-TimeWidth} {endText,-TimeWidth} {block.Category,-CategoryWidth} {FormatDuration(block.Duration),DurationWidth} {status,-StatusWidth}");
		}

		Console.WriteLine();
	}

	if (days.Count == 0)
	{
		Console.WriteLine("No completed time blocks found.");
	}
}

string FormatDuration(TimeSpan duration)
{
	var totalHours = (int)duration.TotalHours;
	return $"{totalHours:D2}:{duration.Minutes:D2}:{duration.Seconds:D2}";
}

internal sealed record EventEntry(DateTimeOffset Timestamp, string Kind, int LineNumber);

internal sealed record TimeBlock(string Category, DateTimeOffset Start, DateTimeOffset End, bool IsOngoing = false)
{
	public TimeSpan Duration => End - Start;
}