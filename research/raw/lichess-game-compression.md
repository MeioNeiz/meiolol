# Developer update: 275% improved game compression • Lichess's Blog • lichess.org

<https://lichess.org/@/lichess/blog/developer-update-275-improved-game-compression/Wqa7GiAA>

[

lichess.org

](https://lichess.org/)

[Play](https://lichess.org/)

[Create lobby game](https://lichess.org/?any#hook)[Arena tournaments](https://lichess.org/tournament)[Swiss tournaments](https://lichess.org/swiss)[Simultaneous exhibitions](https://lichess.org/simul)

[Puzzles](https://lichess.org/training)

[Puzzles](https://lichess.org/training)[Puzzle Themes](https://lichess.org/training/themes)[Puzzle Dashboard](https://lichess.org/training/dashboard/30)[Puzzle Streak](https://lichess.org/streak)[Puzzle Storm](https://lichess.org/storm)[Puzzle Racer](https://lichess.org/racer)

[Learn](https://lichess.org/learn)

[Chess basics](https://lichess.org/learn)[Practice](https://lichess.org/practice)[Coordinates](https://lichess.org/training/coordinate)[Study](https://lichess.org/study)[Coaches](https://lichess.org/coach)

[Watch](https://lichess.org/broadcast)

[Broadcasts](https://lichess.org/broadcast)[Lichess TV](https://lichess.org/tv)[Current games](https://lichess.org/games)[Streamers](https://lichess.org/streamer)[Video library](https://lichess.org/video)

[Community](https://lichess.org/player)

[Players](https://lichess.org/player)[Teams](https://lichess.org/team)[Forum](https://lichess.org/forum)[Blog](https://lichess.org/blog/community)

[Tools](https://lichess.org/analysis)

[Analysis board](https://lichess.org/analysis)[Openings](https://lichess.org/opening)[Board editor](https://lichess.org/editor)[Import game](https://lichess.org/paste)[Advanced search](https://lichess.org/games/search)

[Donate](https://lichess.org/patron)

[Sign in](https://lichess.org/login?referrer=/@/lichess/blog/developer-update-275-improved-game-compression/Wqa7GiAA)[Register](https://lichess.org/signup)

[Community](https://lichess.org/blog/community)[By month](https://lichess.org/blog/monthly)[By topic](https://lichess.org/blog/topic)[By Lichess](https://lichess.org/@/lichess/blog)

[My likes](https://lichess.org/blog/liked)

# Developer update: 275% improved game compression

[Lichess](https://lichess.org/@/Lichess/blog)12 Mar 2018**7,611** viewsEnglish (US)

**Storing games efficiently with move ordering heuristics and Huffman coding**

Our database runs on 3 servers (1 primary, 2 secondaries), each with two 480GB SSDs in a RAID 1 configuration, and one server with a 1h delayed replica. We need more storage space, so we're upgrading the servers and we're also trying to store the games more efficiently. This post explains some technical details of the new storage format.

_Spoiler alert: The new encoding saves some space._

MongoDB supports transparent Snappy and zlib compression, but it's clear that we can use chess knowledge to perform better than general purpose compression schemes. There are [many known approaches](https://triplehappy.wordpress.com/2015/10/26/chess-move-compression/). It's all about striking a balance between simplicity of implementation, performance, and compression ratio.

_The encoder needs to touch thousands of games per second._

Similar to [the way we're compressing clock times](https://lichess.org/blog/WOEVrjAAALNI-fWS/a-better-game-clock-history), compression works in two steps:

1.  Map moves to integer indexes. The smaller on average the better.
2.  Encode those integers as a stream of bits.

## Legal move generation

We're trying to map moves to small integers. The first bit of chess knowledge we're going to use is move legality. The maximum number of moves in a chess position [seems to be 218](https://chessprogramming.wikispaces.com/Encoding%20Moves#MoveIndex), but definitely less than 256. That already narrows it down a lot. (We could stop here, if we were satisfied with 1 byte per move).

To generate legal moves, most chess engines use [bitboards](https://chessprogramming.wikispaces.com/Bitboards) (unsigned 64-bit integers) as a way to represent sets of squares. Java has no unsigned integers, but surprisingly (to me) longs are good enough for bitboards: Java has a zero-filling shift operator (>>>), bitwise operations do not treat the sign-bit in a special way, and integer multiplication (used for [magic bitboards](https://chessprogramming.wikispaces.com/Magic+Bitboards)) also does not care about signedness. [Long.numberOfTrailingZeros()](https://docs.oracle.com/javase/8/docs/api/java/lang/Long.html#numberOfTrailingZeros-long-) can be used for fast bitscans. This means we can easily [port](https://github.com/lichess-org/compression/blob/49c75b1eee39a85f9bdfe886bd975c814085fe3d/src/main/java/game/Board.java#L257) Stockfish's legal move generation.

## Ordering moves

_The more left-skewed the histogram, the better the compression._

Not all of the legal moves in a position are equally likely to be played. Most games on Lichess are actually decent chess and far from random. By ordering the candidate moves sensibly we can ensure that smaller indexes are picked on average.

Fully evaluating each move is way too expensive (and also a bit fragile), so we experimented with some very basic criteria. Along the way I ended up implementing the compression scheme in three different languages:

-   [Python](https://gist.github.com/niklasf/933053f76a418cfe4d52f2f1af997c6f), using [python-chess](https://github.com/niklasf/python-chess), because it allowed for quick prototyping. Experiments on [big PGNs](https://database.lichess.org/) had to run over night.
-   Then [Rust](https://github.com/niklasf/rust-pgn-reader/blob/compression-example/examples/compression.rs) with [shakmaty](https://crates.io/crates/shakmaty), [rust-pgn-reader](https://crates.io/crates/pgn-reader) and [rust-huffman-compress](https://crates.io/crates/huffman-compress), which are much faster than the Python equivalents and allowed fine-tuning in minutes rather than days.
-   And finally [Java](https://github.com/lichess-org/compression/tree/master/src/main/java/game), so it can run in the JVM like the rest of Lichess. The legal move list can be reused for reading and writing standard algebraic notation, so that reading a 40 move game takes around 100 microseconds.

Weights for various criteria were tuned with [SPSA](http://www.jhuapl.edu/SPSA/). For now we [settled on these](https://github.com/lichess-org/compression/blob/49c75b1eee39a85f9bdfe886bd975c814085fe3d/src/main/java/game/Move.java#L25-L44), in a strict order of precedence:

1.  If available, pawn **promotions** are more likely to be played than other moves.
2.  Prefer **captures**.
3.  Valuable pieces are rarely moved onto squares **defended by pawns**.
4.  Usually moves make sense positionally, e.g. centralizing pieces. We use a **piece-square table** [ripped out of a chess engine](https://github.com/flok99/feeks/blob/f02e4897555ac08497a5fea43f241bad30f2ecff/psq.py#L8-L67).
5.  The order should never allow ties, or else it would leak implementation details. **Break ties** lexicographically.

## Huffman coding

Now that we mapped the moves to a list of integer indexes we can encode them as a stream of bits, reusing [Isaacly's fast bit writer](https://github.com/lichess-org/compression/blob/master/src/main/java/BitWriter.java) from the clock time compression.

[Huffman coding](https://en.wikipedia.org/wiki/Huffman_coding) is easy to implement, and ([almost](https://en.wikipedia.org/wiki/Huffman_coding#Optimality)) optimal when looking at the symbols independently. It works by representing the integer indexes as a set of loose leaves, with weights according to their frequency. Then repeatedly the two lightest nodes are grouped together.

_Building a Huffman tree. The weightless nodes were actually given an ϵ weight to break ties._

The result is a binary tree that can be used to read off a unique binary encoding for each index, where more heavy nodes get shorter bitstrings.

_The Huffman tree: For example in the starting position 1. d4 is encoded as 100 (right, left, left)._

## What's next

The [code is published on GitHub](https://github.com/lichess-org/compression/tree/master/src/main/java/game). This was a fun project, even though it didn't involve any shiny new features. Your live games are already being encoded with the new format and Thibault wrote a [script that is currently migrating existing games](https://github.com/ornicar/lichess-game-migration). The lichess database contains 680 million games (as of 2018/03/12) so we expect to gain about 70 GB right now and significantly slow the growth of the database from now on.

As always, comments, questions and suggestions are welcome.

[Mastodon](https://mastodon.online/@lichess)[GitHub](https://github.com/lichess-org)[Discord](https://discord.gg/lichess)[Bluesky](https://bsky.app/profile/lichess.org)[YouTube](https://youtube.com/@LichessDotOrg)[Twitch](https://www.twitch.tv/lichessdotorg)

[Lichess is a charity and entirely free/libre open source software. We depend on user donations to support our operating costs, development, and content. Without our generous community, we would not be able to keep the site running. Thank you for joining us!](https://lichess.org/patron)

## You may also like

[19 Apr 2024revoof

## Adapting nnue-pytorch's binary position format for Lichess

Lichess stores lots of chess positions, and (thanks to Stockfish) now more efficiently](https://lichess.org/@/revoof/blog/adapting-nnue-pytorchs-binary-position-format-for-lichess/cpeeAMeY)[7 Jan 2026Lichess

## Lichess: End of Year Update 2025

Is it just us, or has this year flown by? As we say goodbye to 2025 and enter 2026, let's look back …](https://lichess.org/@/Lichess/blog/lichess-end-of-year-update-2025/YRiNKoaQ)[27 Feb 2024Lichess

## Lichess Broadcast Updates

Following the loss of Chess24 as a platform to follow live chess events, and spurred on by community…](https://lichess.org/@/Lichess/blog/lichess-broadcast-updates/EXh5SchG)[19 Apr 2025Lichess

## Interview: Ju Wenjun - Women's World Chess Champion 2025

Lichess interviewed GM Ju Wenjun after she won her fifth Women's World Chess Championship title.](https://lichess.org/@/Lichess/blog/interview-ju-wenjun-womens-world-chess-champion-2025/2hGmA5vM)[14 Nov 2025Lichess

## FIDE World Cup R4: Praggnanandhaa, Keymer, Vachier-Lagrave, Blübaum Eliminated

GM Daniil Dubov eliminated GM Praggnanandhaa R, while GM Andrey Esipenko got the better of GM Vincen…](https://lichess.org/@/Lichess/blog/fide-world-cup-r4-praggnanandhaa-keymer-vachier-lagrave-blubaum-eliminated/dldDR5u8)[15 Mar 2024marcusbuffett

## Compressing Chess Moves Even Further, To 3.7 Bits Per Move

Chess moves in standard notation take 16 to 56 bits. How low can we go?](https://lichess.org/@/marcusbuffett/blog/compressing-chess-moves-even-further-to-37-bits-per-move/YgugQc42)
