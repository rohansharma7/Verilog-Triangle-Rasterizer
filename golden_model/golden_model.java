public class golden_model {
    static final int width = 20;
    static final int height = 20;
    
    static int[][] screen = new int[width][height];
    
    
    
    public static int edge(int x1, int y1, int x2, int y2, int px, int py) {
        return (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1);
    }


    public static void clearScreen() {
        for (int i = 0; i < width; i ++) {
            for (int j = 0; j < height; j++) {
                screen[i][j] = 0;
            }
        }
    }

    public static void printScreen() {
        for (int i = 0; i < width; i ++) {
            for (int j = 0; j < height; j++) {
                System.out.print(screen[i][j]);
            }
            System.out.println();
        }
    }
    
    public static void fillTriangle(int x1, int y1, int x2, int y2, int x3, int y3) {
        int maxX = x1;
        int maxY = y1;
        if (maxX < x2) {
            maxX = x2;
        }
        if (maxX < x3) {
            maxX = x3;
        }
        if (maxY < y2) {
            maxY = y2;
        }
        if (maxY < y3) {
            maxY = y3;
        }

        int minX = x1;
        int minY = y1;
        if (minX > x2) {
            minX = x2;
        }
        if (minX > x3) {
            minX = x3;
        }
        if (minY > y2) {
            minY = y2;
        }
        if (minY > y3) {
            minY = y3;
        }

        for (int i = minX; i <= maxX; i++) {
            for (int j = minY; j <= maxY; j++) {
                if (edge(x1, y1, x2, y2, i, j) > 0 && edge(x2, y2, x3, y3, i, j) > 0 && edge(x3, y3, x1, y1, i, j) > 0) {
                    screen[i][j] = 5;
                }
            }
        }        
    }

 
    
    public static void main(String[] args) {
        clearScreen();




        fillTriangle(0, 0, 5, 0, 0, 5);



        printScreen();
    }
}


