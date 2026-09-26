#include <stdint.h>

#define WORD_COUNT          256u
#define BYTE_COUNT          (WORD_COUNT * sizeof(uint32_t))

#define BRAM_BASE           0xC0000000u
#define INPUT_BUFFER        BRAM_BASE
#define SCRATCH_BUFFER      (BRAM_BASE + BYTE_COUNT)

#define DMA_BASE            0x41E10000u
#define MM2S_DMACR          0x00u
#define MM2S_DMASR          0x04u
#define MM2S_SA             0x18u
#define MM2S_LENGTH         0x28u
#define S2MM_DMACR          0x30u
#define S2MM_DMASR          0x34u
#define S2MM_DA             0x48u
#define S2MM_LENGTH         0x58u

#define DMA_RUN_STOP        0x00000001u
#define DMA_IOC_IRQ         0x00001000u
#define DMA_IRQ_MASK        0x00007000u

static inline void dma_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(DMA_BASE + offset) = value;
}

static inline uint32_t dma_read(uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(DMA_BASE + offset);
}

static void dma_receive(uint32_t address)
{
    dma_write(S2MM_DMASR, DMA_IRQ_MASK);
    dma_write(S2MM_DMACR, DMA_RUN_STOP);
    dma_write(S2MM_DA, address);
    dma_write(S2MM_LENGTH, BYTE_COUNT);

    while ((dma_read(S2MM_DMASR) & DMA_IOC_IRQ) == 0u) {
    }

    dma_write(S2MM_DMASR, DMA_IRQ_MASK);
}

static void dma_transmit(uint32_t address)
{
    dma_write(MM2S_DMASR, DMA_IRQ_MASK);
    dma_write(MM2S_DMACR, DMA_RUN_STOP);
    dma_write(MM2S_SA, address);
    dma_write(MM2S_LENGTH, BYTE_COUNT);

    while ((dma_read(MM2S_DMASR) & DMA_IOC_IRQ) == 0u) {
    }

    dma_write(MM2S_DMASR, DMA_IRQ_MASK);
}

static void radix_sort_u32(volatile uint32_t *input, volatile uint32_t *scratch)
{
    uint32_t histogram[WORD_COUNT];
    volatile uint32_t *source = input;
    volatile uint32_t *destination = scratch;
    volatile uint32_t *swap;
    uint32_t shift;
    uint32_t i;

    for (shift = 0u; shift < 32u; shift += 8u) {
        for (i = 0u; i < WORD_COUNT; ++i) {
            histogram[i] = 0u;
        }

        for (i = 0u; i < WORD_COUNT; ++i) {
            ++histogram[(source[i] >> shift) & 0xffu];
        }

        {
            uint32_t total = 0u;
            for (i = 0u; i < WORD_COUNT; ++i) {
                uint32_t count = histogram[i];
                histogram[i] = total;
                total += count;
            }
        }

        for (i = 0u; i < WORD_COUNT; ++i) {
            uint32_t value = source[i];
            destination[histogram[(value >> shift) & 0xffu]++] = value;
        }

        swap = source;
        source = destination;
        destination = swap;
    }
}

int main(void)
{
    volatile uint32_t *const input = (volatile uint32_t *)(uintptr_t)INPUT_BUFFER;
    volatile uint32_t *const scratch = (volatile uint32_t *)(uintptr_t)SCRATCH_BUFFER;

    for (;;) {
        dma_receive(INPUT_BUFFER);
        radix_sort_u32(input, scratch);
        dma_transmit(INPUT_BUFFER);
    }
}
