#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define main firmware_main
#include "../workspace/app/src/main.c"
#undef main
static uint32_t random_state=0x180008u;
static uint32_t rnd(void) {
    random_state ^= random_state<<13;
    random_state ^= random_state>>17;
    random_state ^= random_state<<5;
    return random_state;
}
static int cmp(const void *a, const void *b) {
    uint32_t x=*(const uint32_t*)a, y=*(const uint32_t*)b;
    return (x>y)-(x<y);
}
int main(void) {
    struct guarded { uint32_t pre,words[256],post; } a,b;
    uint32_t expected[256];
    for(unsigned t=0;t<10008;t++) {
        a.pre=b.pre=0x12345678u;a.post=b.post=0xabcdef01u;
        for(unsigned i=0;i<256;i++) {
            uint32_t x;
            switch(t) {
                case 0: x=0;break;
                case 1: x=UINT32_MAX;break;
                case 2: x=i;break;
                case 3: x=255-i;break;
                case 4: x=(i&1)?0x80000000u:0x7fffffffu;break;
                case 5: x=1u<<(i%32);break;
                case 6: x=(i&1)?UINT32_MAX:0;break;
                case 7: x=i%7;break;
                default:x=rnd();break;
            }
            a.words[i]=expected[i]=x;b.words[i]=rnd();
        }
        qsort(expected,256,sizeof(uint32_t),cmp);
        radix_sort_u32(a.words,b.words);
        if(memcmp(a.words,expected,sizeof(expected)) || a.pre!=0x12345678u || b.pre!=0x12345678u || a.post!=0xabcdef01u || b.post!=0xabcdef01u) {
            fprintf(stderr,"FAIL case %u\n",t);return 1;
        }
    }
    puts("PASS 10008 vectors; unsigned qsort reference; canaries intact");
    return 0;
}
