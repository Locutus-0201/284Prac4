#include <stdio.h>

extern float testDeliverable1();

int main()
{
    float marks = testDeliverable1();
    printf("Total Marks %.f\n", marks);

    return 0;
}