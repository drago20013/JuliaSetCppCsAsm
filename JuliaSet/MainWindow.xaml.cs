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
        private static unsafe extern void CalculateMandelbrotASM(ComplexCoord* inCoord, Pixel* outBMP, int width, int height);

        [DllImport("AsmDll.dll")]
        private static unsafe extern void Dummy();
        public struct Pixel
        {
            public int r; //32-bits
            public int g;
            public int b;
            public int a;
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
            public float x; //32-bits
            public float y;
        }

        public MainWindow()
        {
            InitializeComponent();

            int width = (int)image.Width;
            int height = (int)image.Height;

            ComplexCoord[] complexCoords = new ComplexCoord[width * height];
            ComplexCoord[] complexCoordsASM = new ComplexCoord[width * height];
            Pixel[] outBMP = new Pixel[width * height];
            Pixel[] outBMPASM = new Pixel[width * height];
            for (int i = 0; i < width * height; i++) outBMP[i] = new Pixel();
            for (int i = 0; i < width * height; i++) outBMPASM[i] = new Pixel();

            //==============================
            InitData(complexCoords, width, height);

            var watch = new System.Diagnostics.Stopwatch();
            var watch2 = new System.Diagnostics.Stopwatch();

            watch.Start();
            CalculateMandelbrot(complexCoords, outBMP, width, height);
            watch.Stop();

            cTime.Text = watch.ElapsedMilliseconds.ToString() + "ms.";

            Bitmap bitmap = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
            System.Drawing.Color pixelColor;

            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb((int)outBMP[y * width + x].a, (int)outBMP[y * width + x].r, (int)outBMP[y * width + x].g, (int)outBMP[y * width + x].b);
                    bitmap.SetPixel(x, y, pixelColor);
                }

            bitmap.Save("../../../JuliaSet/images/Set.png");
            image.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSet\\JuliaSet\\images\\Set.png", UriKind.Absolute));

            //==============================
            InitData(complexCoordsASM, width, height);

            unsafe
            {
                fixed(ComplexCoord* inCoordAddr = complexCoordsASM)
                {
                    fixed(Pixel* outBMPAddr = outBMPASM)
                    {
                        CalculateMandelbrotASM(inCoordAddr, outBMPAddr, width, height);
                        watch2.Start();
                        CalculateMandelbrotASM(inCoordAddr, outBMPAddr, width, height);
                        watch2.Stop();
                    }
                }
            }

            asmTime.Text = watch2.ElapsedMilliseconds.ToString() + "ms.";

            Bitmap bitmapASM = new(width, height, System.Drawing.Imaging.PixelFormat.Format32bppPArgb);

            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    pixelColor = System.Drawing.Color.FromArgb((int)outBMPASM[y * width + x].a, (int)outBMPASM[y * width + x].r, (int)outBMPASM[y * width + x].g, (int)outBMPASM[y * width + x].b);
                    bitmapASM.SetPixel(x, y, pixelColor);
                }

            bitmapASM.Save("../../../JuliaSet/images/Set2.png");
            image2.Source = new BitmapImage(new Uri("C:\\Users\\Michal\\source\\repos\\JuliaSet\\JuliaSet\\images\\Set2.png", UriKind.Absolute));
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

        public static void CalculateMandelbrot(ComplexCoord[] inComplexCoord, Pixel[] outBMP, int width, int height)
        {
            int maxIterations = 255;
            //C = ca + cb*i
            float ca; //C real part
            float cb; //C imaginary part
            //Z = a+b*i
            //double a; //Z real part 
            //double b; //Z imaginary part

            for (int i = 0; i < height * width; ++i)
            {
                //For each pixel coordinate
                //ca = inComplexCoord[i].x; // C real part is equal to the real part mapped from coordinates
                //cb = inComplexCoord[i].y; // C imaginary part is equal to the real part mapped from coordinates

                // When instead of having different C number for each pixel we asign it to specific number for all pixels we get Julia Set.
                ca = -0.4f;
                cb = -0.59f;
                int n;

                for (n = 0; n < maxIterations; ++n)
                {
                    //Z = Z^2 + C

                    //Z^2
                    float aa = inComplexCoord[i].x * inComplexCoord[i].x - inComplexCoord[i].y * inComplexCoord[i].y; // new Z^2 real part
                    float bb = 2 * inComplexCoord[i].x * inComplexCoord[i].y; // new Z^2 imaginary part

                    //Z = Z^2 + C, Z = a + bi, so Z = Z^2 + C is Z = (aa + ca) + (bb + cb)i
                    inComplexCoord[i].x = aa + ca; //Z real 
                    inComplexCoord[i].y = bb + cb;

                    //Condition for determaining if the Z for given coordinates is bounded, can be adjusted
                    if (Math.Abs(inComplexCoord[i].x + inComplexCoord[i].y) > 16)
                    {
                        break;
                    }
                }

                //Nice gray scale coloring, we can do it with actual colors, also doesn't matter for logic part 
                //outBMP[i].r = (int)Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                //outBMP[i].g = (int)Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);
                //outBMP[i].b = (int)Remap((float)Math.Sqrt(Remap(n, 0, maxIterations, 0, 1)), 0, 1, 0, 255);

                if (n == maxIterations)
                {
                    outBMP[i].r = 0;
                    outBMP[i].g = 0;
                    outBMP[i].b = 0;
                }
                else
                {
                    outBMP[i].r = n;
                    outBMP[i].g = n;
                    outBMP[i].b = n;
                }
            }
        }

        private static float Remap(float source, float sourceFrom, float sourceTo, float targetFrom, float targetTo)
        {
            return targetFrom + (source - sourceFrom) * (targetTo - targetFrom) / (sourceTo - sourceFrom);
        }
    }
}
