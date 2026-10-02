/* Minimal framebuffer helper for the SM-T280 sprdfb panel (freestanding,
 * raw syscalls). The panel only refreshes on FBIOPAN_DISPLAY.
 *   fbpan info        print resolution / offsets
 *   fbpan pan N       unblank and display page N (yoffset = N * yres)
 *   fbpan loop MS     keep re-panning page 0 every MS milliseconds, so that
 *                     plain framebuffer clients (Xorg fbdev) reach the panel
 */
typedef unsigned int u32;
struct fb_bitfield { u32 offset, length, msb_right; };
struct fb_var_screeninfo {
    u32 xres, yres, xres_virtual, yres_virtual, xoffset, yoffset;
    u32 bits_per_pixel, grayscale;
    struct fb_bitfield red, green, blue, transp;
    u32 nonstd, activate, height, width, accel_flags;
    u32 pixclock, left_margin, right_margin, upper_margin, lower_margin;
    u32 hsync_len, vsync_len, sync, vmode, rotate, colorspace, reserved[4];
};
#define FBIOGET_VSCREENINFO 0x4600
#define FBIOPAN_DISPLAY     0x4606
#define FBIOBLANK           0x4611
static long sc(long nr, long a, long b, long c)
{
    register long r0 __asm__("r0")=a, r1 __asm__("r1")=b, r2 __asm__("r2")=c;
    register long r7 __asm__("r7")=nr;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1),"r"(r2),"r"(r7) : "memory","cc");
    return r0;
}
static unsigned long slen(const char *s) { unsigned long n=0; while(s[n]) n++; return n; }
static void out(const char *s) { sc(4,1,(long)s,slen(s)); }
static void num(long v)
{
    char b[16]; int i=sizeof(b); unsigned long x=v<0?-v:v;
    do { b[--i]='0'+x%10; x/=10; } while(x);
    if(v<0) b[--i]='-';
    sc(4,1,(long)(b+i),sizeof(b)-i);
}
static int same(const char *a, const char *b) { while(*a && *a==*b) { a++; b++; } return *a==*b; }
static void quit(int c) { sc(1,c,0,0); for(;;) {} }
void main_c(int argc, char **argv)
{
    struct fb_var_screeninfo v; int fd; long r;
    fd=sc(5,(long)"/dev/fb0",2,0);
    if(fd<0) { out("open /dev/fb0 failed "); num(fd); out("\n"); quit(1); }
    r=sc(54,fd,FBIOGET_VSCREENINFO,(long)&v);
    if(r) { out("FBIOGET_VSCREENINFO "); num(r); out("\n"); quit(1); }
    out("xres="); num(v.xres); out(" yres="); num(v.yres); out(" vyres="); num(v.yres_virtual);
    out(" yoffset="); num(v.yoffset); out(" bpp="); num(v.bits_per_pixel); out("\n");
    if(argc>=3 && same(argv[1],"loop")) {
        long ms=0, ts[2]; const char *q=argv[2];
        while(*q>='0' && *q<='9') ms=ms*10+(*q++-'0');
        if(ms<10) ms=10;
        ts[0]=ms/1000; ts[1]=(ms%1000)*1000000;
        sc(54,fd,FBIOBLANK,0);
        for(;;) {
            v.xoffset=0; v.yoffset=0;
            sc(54,fd,FBIOPAN_DISPLAY,(long)&v);
            sc(162,(long)ts,0,0);   /* nanosleep */
        }
    }
    if(argc>=3 && same(argv[1],"pan")) {
        long page=argv[2][0]-'0';
        r=sc(54,fd,FBIOBLANK,0); out("unblank="); num(r);
        v.xoffset=0; v.yoffset=page*v.yres;
        r=sc(54,fd,FBIOPAN_DISPLAY,(long)&v); out(" pan="); num(r); out("\n");
    }
    quit(0);
}
__asm__(".global _start\n_start:\n ldr r0,[sp]\n add r1,sp,#4\n bl main_c\n");
