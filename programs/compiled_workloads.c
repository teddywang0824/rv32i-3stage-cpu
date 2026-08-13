#include <stdint.h>

volatile uint32_t signature[8];
static uint32_t source_words[8] = {3, 1, 4, 1, 5, 9, 2, 6};
static uint32_t copied_words[8];

__attribute__((noinline))
static uint32_t leaf_mix(uint32_t a, uint32_t b)
{
    return (a << 1) + b;
}

__attribute__((noinline))
static uint32_t call_chain(uint32_t value)
{
    uint32_t first = leaf_mix(value, 7);
    return leaf_mix(first, 3) ^ 0x55u;
}

__attribute__((noinline))
static uint32_t stack_frame_test(uint32_t seed)
{
    volatile uint32_t local[8];
    uint32_t total = 0;

    for (uint32_t i = 0; i < 8; ++i)
        local[i] = seed + i;
    for (uint32_t i = 0; i < 8; ++i)
        total += local[i] ^ (i << 4);
    return total;
}

__attribute__((noinline))
static uint32_t copy_and_checksum(uint32_t *destination,
                                  const uint32_t *source,
                                  uint32_t count)
{
    uint32_t checksum = 0;
    for (uint32_t i = 0; i < count; ++i) {
        destination[i] = source[i];
        checksum = (checksum << 1) ^ destination[i];
    }
    return checksum;
}

__attribute__((noinline))
static uint32_t branch_heavy_loop(void)
{
    uint32_t accumulator = 0;
    for (uint32_t i = 0; i < 64; ++i) {
        if (i & 1u)
            accumulator += i;
        else
            accumulator ^= i << 1;

        if ((i & 7u) == 0)
            accumulator += 3;
        else
            accumulator -= 1;
    }
    return accumulator;
}

int main(void)
{
    uint32_t failures = 0;
    uint32_t bss_or = 0;

    for (uint32_t i = 0; i < 8; ++i)
        bss_or |= copied_words[i];

    signature[0] = bss_or;
    signature[1] = call_chain(11);
    signature[2] = stack_frame_test(0x20);
    signature[3] = copy_and_checksum(copied_words, source_words, 8);
    signature[4] = branch_heavy_loop();

    if (signature[0] != 0x00000000u) failures |= 1u << 0;
    if (signature[1] != 0x00000068u) failures |= 1u << 1;
    if (signature[2] != 0x000001dcu) failures |= 1u << 2;
    if (signature[3] != 0x0000015eu) failures |= 1u << 3;
    if (signature[4] != 0x00000620u) failures |= 1u << 4;
    for (uint32_t i = 0; i < 8; ++i)
        if (copied_words[i] != source_words[i]) failures |= 1u << 5;

    signature[5] = failures;
    return failures == 0 ? 0 : 1;
}
