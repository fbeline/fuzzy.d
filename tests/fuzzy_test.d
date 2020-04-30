module fuzzyd_test;

import std.stdio;
import std.array;
import std.algorithm;
import std.algorithm.comparison : equal;
import std.container.binaryheap;
import std.range;

import fuzzyd.core;

private FuzzyResult[] prepare(string s)
{
    string[] source = [
        "cd Documents", "curl localhost/foo", "cp bar ../foo",
        "rm -rf Downloads", "vi ~/Documents"
    ];
    FuzzyResult[] response = new FuzzyResult[source.length];
    fuzzy(source)(s, response);
    return heapify!"a.score < b.score"(response).take(source.length).array;
}

@("Matches in expected order")
unittest
{
    auto result = prepare("docts").map!(x => x.value);
    const expected = [
        "cd Documents", "vi ~/Documents", "curl localhost/foo",
        "rm -rf Downloads", "cp bar ../foo"
    ];
    assert(equal(expected, result));
}

@("Matches indexes")
unittest
{
    auto result = prepare("docts")[0].matches;
    const expected = [0, 1, 3, 4, 5, 10, 11];
    assert(equal(expected, result.sort));
}

@("Result is empty if provided db is empty")
unittest
{
    string[] source = [];
    FuzzyResult[] result = new FuzzyResult[0];
    fuzzy(source)("f", result);
    assert(result.empty);
}

@("Unicode support")
unittest
{
    string[] source = ["férias"];
    auto result = new FuzzyResult[source.length];
    fuzzy(source)("fé", result);
    assert(equal([0, 1], result[0].matches.sort));
}

@("Total amount of matches")
unittest
{
    string[] source = [
        "cd Documents", "curl localhost/foo", "cp bar ../foo",
        "rm -rf Downloads", "vi ~/Documents"
    ];
    FuzzyResult[] response = new FuzzyResult[source.length];
    const total = fuzzy(source)("doc", response);
    assert(total == 4);
}