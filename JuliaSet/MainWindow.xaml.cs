using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using static System.Net.Mime.MediaTypeNames;

namespace JuliaSet
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        [DllImport("AsmDll.dll")]
        private static unsafe extern void JuliaAsm(ComplexCoord* inCoord, Pixel* outBMP, UserSettings settings);
        [DllImport("CDll.dll")]
        private static unsafe extern void JuliaCpp(ComplexCoord* inCoord, Pixel* outBMP, UserSettings settings);

        public struct Pixel
        {
            public float r; //32-bits
            public float g;
            public float b;
            public float a;
            public Pixel()
            {
                r = 255;
                g = 255;
                b = 255;
                a = 255;
            }
        }
        public struct ComplexCoord
        {
            public float x; //32-bits  xxxxxxxxxxxxxxxx... xxxx yyyyyyyy...yyyy
            public float y; //      
        }

        public struct UserSettings
        {
            public float c_real;
            public float c_imag;
            public int size;
            public int maxIter;
            public UserSettings(float c_r, float c_im, int size, int maxIter)
            {
                c_real = c_r;
                c_imag = c_im;
                this.size = size;
                this.maxIter = maxIter;
            }
        }

        public MainWindow()
        {
            InitializeComponent();

            int width = (int)image.Width;
            int height = (int)image.Height;

/*            int width = 2;
            int height = 2;*/
            int size = width * height;

            ComplexCoord[] newComplexCoord = new ComplexCoord[size];
            ComplexCoord[] newComplexCoordCPP = new ComplexCoord[size];
            ComplexCoord[] newComplexCoordASM = new ComplexCoord[size];
            UserSettings settings = new UserSettings(-0.8f, 0.156f, size, 255);

            Pixel[] outBMP = new Pixel[width * height];
            Pixel[] outBMPASM = new Pixel[width * height];
            Pixel[] outBMPCPP = new Pixel[width * height];
            for (int i = 0; i < size; i++) outBMP[i] = new Pixel();
            for (int i = 0; i < size; i++) outBMPASM[i] = new Pixel();
            for (int i = 0; i < size; i++) outBMPCPP[i] = new Pixel();

            //==============================
            InitData(newComplexCoord, width, height);
            InitData(newComplexCoordASM, width, height);
            InitData(newComplexCoordCPP, width, height);

            var watch = new System.Diagnostics.Stopwatch();
            float time = 0.0f;
            JuliaSet(newComplexCoord, outBMP, settings);
            for (int i = 0; i < 10; i++)
            {
                InitData(newComplexCoord, width, height);
                watch.Start();
                JuliaSet(newComplexCoord, outBMP, settings);
                watch.Stop();
                time += watch.ElapsedMilliseconds;
            }
            time = time / 10;
            cTime.Text = time.ToString() + "ms.";

            //==============================
            time = 0;
            unsafe
            {
                fixed (ComplexCoord* cordAddr = newComplexCoordASM)
                {
                    fixed (Pixel* outBMPAddr = outBMPASM)
                    {
                        JuliaAsm(cordAddr, outBMPAddr, settings);
                        for (int i = 0; i < 10; i++)
                        {
                            InitData(newComplexCoordASM, width, height);
                            watch.Start();
                            JuliaAsm(cordAddr, outBMPAddr, settings);
                            watch.Stop();
                            time += watch.ElapsedMilliseconds;
                        }
                    }
                }
            }

            time = time / 10;
            asmTime.Text = time.ToString() + "ms.";
            time = 0;
            unsafe
            {
                fixed (Pixel* outBMPAddr = outBMPCPP)
                {
                    fixed (ComplexCoord* newCoordCPPAddr = newComplexCoordCPP)
                    {
                        JuliaCpp(newCoordCPPAddr, outBMPAddr, settings);
                        for (int i = 0; i < 10; i++)
                        {
                            InitData(newComplexCoordCPP, width, height);
                            watch.Start();
                            JuliaCpp(newCoordCPPAddr, outBMPAddr, settings);
                            watch.Stop();
                            time += watch.ElapsedMilliseconds;
                        }
                    }
                }
            }

            time = time / 10;
            cppTime.Text = time.ToString() + "ms.";

            Bitmap bitmap = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
            System.Drawing.Color pixelColor;

            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb(255, (int)outBMPCPP[y * width + x].r, (int)outBMPCPP[y * width + x].g, (int)outBMPCPP[y * width + x].b);
                    bitmap.SetPixel(x, y, pixelColor);
                }

            bitmap.Save("../../../JuliaSet/images/Set.png");
            image.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSetCppCsAsm\\JuliaSet\\images\\Set.png", UriKind.Absolute));

            Bitmap bitmapASM = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);

            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb(255, (int)outBMPASM[y * width + x].r, (int)outBMPASM[y * width + x].g, (int)outBMPASM[y * width + x].b);
                    bitmapASM.SetPixel(x, y, pixelColor);
                }

            bitmapASM.Save("../../../JuliaSet/images/Set2.png");
            image2.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSetCppCsAsm\\JuliaSet\\images\\Set2.png", UriKind.Absolute));
        }
        public static void InitData(ComplexCoord[] inComplexCoord, int width, int height)
        {
            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
                {
                    inComplexCoord[y * width + x].x = Remap(x, 0, width, -1.5f, 1.5f);
                    inComplexCoord[y * width + x].y = Remap(y, 0, height, -1.5f, 1.5f);
                }
            }
        }

        public static void JuliaSet(ComplexCoord[] inComplexCoord, Pixel[] outBMP, UserSettings settings) {
            //Z = Z^2 + C

            int maxIterations = settings.maxIter;
            //C = ca + cb*i
            float ca; //C real part
            float cb; //C imaginary part
            //Z = a+b*i
            //double a; //Z real part 
            //double b; //Z imaginary part

            for (int i = 0; i < settings.size; ++i)
            {
                //For each pixel coordinate
                //ca = inComplexCoord[i].x; // C real part is equal to the real part mapped from coordinates
                //cb = inComplexCoord[i].y; // C imaginary part is equal to the real part mapped from coordinates

                // When instead of having different C number for each pixel we asign it to specific number for all pixels we get Julia Set.
                ca = settings.c_real;
                cb = settings.c_imag;
                int n = 0;

                for (; n < maxIterations; ++n)
                {
                    float aa = inComplexCoord[i].x * inComplexCoord[i].x;
                    float bb = inComplexCoord[i].y * inComplexCoord[i].y;

                    //COMPUTE NEXT
                    //Z = Z^2 + C

                    //Z^2
                    float newReal = aa - bb; // new Z^2 real part
                    float newImag = 2 * inComplexCoord[i].x * inComplexCoord[i].y; // new Z^2 imaginary part

                    //Z = Z^2 + C, Z = a + bi, so Z = Z^2 + C is Z = (aa + ca) + (bb + cb)i
                    inComplexCoord[i].x = newReal + ca; //Z real 
                    inComplexCoord[i].y = newImag + cb;

                    //Condition for determaining if the Z for given coordinates is bounded, can be adjusted
                    if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
                    {
                        break;
                    }
                }

                //Nice gray scale coloring

                if (n == maxIterations)
                {
                    outBMP[i].r = 0;
                    outBMP[i].g = 0;
                    outBMP[i].b = 0;
                }
                else
                {
                    outBMP[i].r = Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                    outBMP[i].g = Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                    outBMP[i].b = Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                }
            }
        }

        private static float Remap(float source, float sourceFrom, float sourceTo, float targetFrom, float targetTo)
        {
            return targetFrom + (source - sourceFrom) * (targetTo - targetFrom) / (sourceTo - sourceFrom);
        }
    }
}
