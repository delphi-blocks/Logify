# Logify: meta-logger for Delphi

<br />

<p align="center">
  <img src="logify.png" alt="Logify Library" width="400" />
</p>

## Logify: what is it?

In modern software development, logging is indispensable for monitoring application health, debugging issues, and understanding user behavior. However, traditional logging approaches in Delphi often lead to tightly coupled code, where your application's business logic directly depends on a specific logging framework's classes and units. This creates a dependency, making it difficult to swap out loggers, introduces unnecessary compilation dependencies, and hinders testability. If you decide to change your logging backend to another solution, you're faced with a potentially large-scale refactoring effort across your entire codebase.

**Logify**, a new meta-logger for Delphi, is designed to liberate your applications from these rigid logging dependencies. Inspired by best practices seen in frameworks like .NET's `ILogger` interface, Logify's primary purpose is to provide a **simple, yet powerful, interface-based abstraction for logging**.

At its core, Logify introduces an `ILogger` interface that your application code will interact with exclusively. This means:

* **No Direct Logger Class Dependency:** Your business units will never directly reference `TMyLoggerSpecificClass` or `MyLoggerUnit.pas`. Instead, they'll simply "ask" for an `ILogger` instance.

* **True Decoupling:** The choice of the underlying logging implementation (e.g., writing to file, database, console, or a third-party logging library) is entirely handled by Logify's configuration and composition layer, completely outside your core application logic.

* **Enhanced Testability:** With an interface-based approach, you can easily mock or stub the `ILogger` interface during unit tests, ensuring that your tests focus purely on the business logic without generating actual log output or requiring a real logging setup.

* **Future-Proofing:** Should your logging requirements change, or a new, superior logging framework emerge, the transition becomes a matter of updating Logify's configuration and providing a new implementation of the `ILogger` interface, rather than modifying hundreds or thousands of lines of application code.

* **Cleaner Codebase:** By centralizing logging concerns behind an interface, your application code remains cleaner, more readable, and focused on its primary responsibilities.

Logify acts as an intelligent proxy or a "meta-logger," providing a unified front for various logging backends. It's about shifting the paradigm from "I use *this* logger" to "I need *a* logger," empowering Delphi developers to build more flexible, maintainable, and robust applications that are ready for evolution. This introduction will explore how Logify achieves this decoupling and how you can leverage its power to revolutionize your Delphi logging strategy.

## When to use Logify

Logify is an easy interface to logging libraries so it makes sense to use it when you are in a situation where you already use more than a logger library, so you have to change your code one more time but... for the last time :-)

Logify is useful also when you use only one logger library because the reason (for me) that Logify was created is to have the possibility to compile some units with some logging in it in other project can may or may not have need for logging. So, actually, the main feature of Logify is not to log but to do absilutely nothing ;-)

Let me explain with a simple example:

```delphi

uses
  MyBeautifulLoggerUnit;

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  if CheckBox1.Checked then
  begin
    Edit1.Text := 'Paolo';
    // This is a fake line that emulates the API of a generic logger
    MyLogger.Log('Setting the value of Edit1', INFO); 
  end;
end;
```

you have code like that in a Form (or a DataModule, or a Unit) that generates lines in an already configured logfile and now you want to use this code in a new project but you don't need a logger right now (eventually you'll configure one)... what are your choiches?

1. Remove all the log lines 
2. IFDEF them
3. Configure the exact same logger (that you don't need)

as you can see all three options require quite some changes to the source code and you have to remember that this unit is shared back with another application!

So what Logify offers as a solution?

```delphi
uses
  Logify;

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  if CheckBox1.Checked then
  begin
    Edit1.Text := 'Paolo';
    // This is a simple call from the Logify interface
    Logger.LogInfo('Setting the value of Edit1');
  end;
end;
```

With Logify you can reuse this piece of code as is it, without removing or modifying nothing. And later, if the need arise, you can configure properly the `Logger` object.

