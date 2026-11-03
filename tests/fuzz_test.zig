const std = @import("std");
const core = @import("nepdate");

test "parser fuzz corpus, seeded" {
    const alphabet = "0123456789-/._\\ |।०१२३४५६७८९abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ \t,BSVगतेमिति";
    var prng = std.Random.DefaultPrng.init(0x0f022081);
    const random = prng.random();
    var input: [96]u8 = undefined;
    var round: usize = 0;
    while (round < 5000) : (round += 1) {
        const length = random.intRangeAtMost(usize, 0, input.len);
        for (input[0..length]) |*byte| {
            if (random.boolean()) {
                byte.* = alphabet[random.intRangeAtMost(usize, 0, alphabet.len - 1)];
            } else {
                byte.* = random.int(u8);
            }
        }
        _ = core.Date.parse(input[0..length]) catch {};
        _ = core.Date.parseLenient(input[0..length]) catch {};
    }
}
