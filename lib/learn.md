1. The "Observer" Weather Aggregator
   Instead of a simple API wrapper, build a system that polls multiple weather APIs simultaneously for different cities.

The Goal: Learn about GenServers and Tasks.

The Skill: Use Elixir’s concurrency to fetch data in parallel rather than sequentially. You can use a GenServer to "hold" the latest weather state in memory so you aren't hitting the API on every page load.

Bonus: Implement a Supervisor that restarts your worker if an API call fails or returns a 500 error.

2. Real-Time Collaborative Markdown Editor
   Use Phoenix LiveView to create a text area where multiple people can type, and the markdown renders instantly for everyone.

The Goal: Master Phoenix Channels and PubSub.

The Skill: LiveView allows you to handle rich, real-time UX without writing a single line of JavaScript. This project will teach you how the state is managed on the server and pushed to the client.

Bonus: Add "presence" to show a list of who else is currently editing the document.

3. A Distributed "Job Runner"
   Build a small application that can take a "job" (like a simulated heavy calculation or image processing task) and distribute it.

The Goal: Understand Pattern Matching and Recursion.

The Skill: Since Elixir doesn't use traditional loops, you'll learn to process lists of jobs using recursion and head/tail matching.

Bonus: Try running two instances of your app and see if you can send a message from a process on Node A to a process on Node B.

4. Personal Finance CLI Tool
   A tool that reads a CSV of bank transactions and categorizes them.

The Goal: Get comfortable with the Enum module and Pipes (|>).

The Skill: Elixir’s pipe operator is its bread and butter. You’ll learn to transform data through a series of clean, readable functions: File.stream! |> CSV.decode |> Enum.filter |> Enum.reduce.

Bonus: Store the results in a PostgreSQL database using Ecto.


====================

Great choice to start with. In Elixir, a Task is the go-to abstraction for running a single, asynchronous piece of work. Since you're coming from Ruby, think of it as a way to "background" a job without needing a heavy external queue like Sidekiq for simple, short-lived operations.Understanding Elixir TasksA Task is a process designed to execute one specific action and then exit. It abstracts away the low-level spawn and receive logic, making your code OTP-compliant (meaning it plays nice with Elixir's supervision and error-handling systems).There are two primary ways to use them for your weather project:Task.async / Task.await: Use this when you need the result back.Scenario: You want to fetch weather from three different APIs at once and wait until they all return so you can average the temperature.Task.start (Fire and Forget): Use this when you don't need a return value.Scenario: Logging a request to a file or a separate analytics service where the main user flow shouldn't wait for it to finish.Example Code: Parallel FetchingElixirdef fetch_all_weather(city) do
# These start immediately and run in parallel
task1 = Task.async(fn -> WeatherApi1.get(city) end)
task2 = Task.async(fn -> WeatherApi2.get(city) end)

# Await both results (waits up to 5 seconds by default)
res1 = Task.await(task1)
res2 = Task.await(task2)

{res1, res2}
end
Suggested Weather APIs (2026 Edition)For a polling project, you want APIs that are reliable, have good JSON structures, and offer a generous free tier. Here are the best bets:API ProviderFree Tier HighlightsBest For...OpenWeatherMap1,000 calls/day (One Call 3.0)The industry standard; great documentation.WeatherAPI.com~1M calls/month (Free tier)High volume polling without hitting limits quickly.Visual Crossing1,000 records/dayExcellent for historical data and timeline-based polling.Tomorrow.io1,000 calls/monthHyper-local data (great if you want to poll every minute).Meteomatics500 queries/dayHigh-resolution data; good for "scientific" feel.Pro Tip: The "Polling" LogicWhile Task is great for the fetching part, you shouldn't use a naked Task for the interval (e.g., "fetch every 10 minutes").For the actual "heartbeat" of your poller, use a GenServer. You can use Process.send_after/3 to send a message to the GenServer itself every 10 minutes. When it receives that message, it can then spawn a Task to do the actual fetching. This keeps your GenServer "responsive" to other requests while the Task does the heavy lifting in the background.Would you like me to show you how to structure that GenServer "heartbeat" to trigger these Tasks?