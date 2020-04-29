module fuzzyd.core;

import std.stdio;
import std.array;
import std.range;
import std.container.rbtree;
import std.container.binaryheap;
import std.math;
import std.conv;
import std.uni;
import std.algorithm.iteration;
import std.algorithm.sorting;

alias fuzzyFn = void delegate(string, ref FuzzyResult[]);
alias bonusFn = double function(Input);

private:

struct Input
{
    dchar i;
    dchar p;
    int col;
    int row;
    double[][] scoreMatrix;

    bool isMatch()
    {
        return i.toLower == p.toLower;
    }

    bool isCaseSensitiveMatch()
    {
        return i.isUpper && p.isUpper && isMatch;
    }
}

double previousCharBonus(Input input)
{
    return (input.col > 0 && input.row > 0) ? 2.5 * input
        .scoreMatrix[input.row - 1][input.col - 1] : 0;
}

double startBonus(Input input)
{
    return (input.col == 0 && input.row == 0) ? 1 : 0;
}

double caseMatchBonus(Input input)
{
    return input.isCaseSensitiveMatch ? 1.5 : 0;
}

void normalize(ref FuzzyResult[] result)
{
    const maxScore = !result.empty ? result[0].score : 1;
    for (long i = 0; i < result.length; i++)
    {
        result[i].score /= maxScore;
    }
}

public:

/// fuzzy search result
struct FuzzyResult
{
    string value; //// entry. e.g "Documents/foo/bar/"
    double score; //// similarity metric. (Higher better)
    RedBlackTree!(int, "a < b", false) matches; //// index of matched characters.
}

/**
 * Fuzzy search
 * Params:
 *   db = Array of string containing the search list.
 * Examples:
 * --------------------
 * fuzzy(["foo", "bar", "baz"])("br");
 * // => [FuzzyResult("bar", 1, RedBlackTree([0, 2])), FuzzyResult("baz", 0.592593, RedBlackTree([0])), FuzzyResult("foo", 0, RedBlackTree([]))]
 * --------------------
 */
fuzzyFn fuzzy(string[] db)
{

    bonusFn[] bonusFns = [
        &previousCharBonus, &startBonus, &caseMatchBonus
    ];

    double charScore(Input input)
    {
        return input.isMatch ? reduce!((acc, f) => acc + f(input))(1.0, bonusFns) : 0;
    }

    FuzzyResult score(string input, string pattern)
    {
        double score = 0;
        double simpleMatchScore = 0;
        double[][] scoreMatrix = new double[][](input.length, pattern.length);
        auto matches = redBlackTree!int();

        int row, col;
        foreach (p; pattern.byCodePoint)
        {
            row = 0;
            foreach (i; input.byCodePoint)
            {
                const charScore = charScore(Input(i, p, col, row, scoreMatrix));
                if (charScore > 0)
                    matches.insert(row);
                if (charScore is 1.0)
                    simpleMatchScore += 1;
                else
                    score += charScore;
                scoreMatrix[row][col] = charScore;
                row++;
            }
            col++;
        }

        const totalScore = score + (simpleMatchScore / 2.0);
        return FuzzyResult(input, totalScore, matches);
    }

    void search(string pattern, ref FuzzyResult[] result)
    {
        // auto maxpq = BinaryHeap!(FuzzyResult[], "a.score < b.score")(result, 0);
        for (int i = 0; i < result.length; i++)
        {
            result[i] = score(db[i], pattern);
        }
        result.sort!("a.score > b.score");
        normalize(result);
    }

    return &search;
}
