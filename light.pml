#define LIGHTS_NUM 6
#define DEF_PRIORITY_INCREASE 1
#define MAX_PRIORITY_INCREASE 200
#define MAX_INTERSECT_NUM 4

// Запросы по дорогам
byte  isLightRequested[LIGHTS_NUM] = {false,false,false,false,false,false};

// Приоритеты по дорогам
short priorityByLights[LIGHTS_NUM] = {0,0,0,0,0,0};

// Текущий статус датчиков по дорогам
bool  isLightGreen[LIGHTS_NUM] = {false,false,false,false,false,false};

byte activeLight = 1;
byte counter = 0;

typedef Conflict {
    byte c[MAX_INTERSECT_NUM];
};

Conflict conflicts[LIGHTS_NUM];

proctype Light(byte id, nextLight; chan lightChan)
{
    byte  quota;

    short curPriority;
    short maxPriority;

    byte  idx;
    byte  lightIdx;

    do
    // DEBUG
    // :: counter > 10 -> break;
    :: activeLight == id ->
        counter++;

        printf("\n turn    :%d", activeLight);
        printf("\n priority:%d,%d,%d,%d,%d,%d",
               priorityByLights[0], priorityByLights[1], priorityByLights[2],
               priorityByLights[3], priorityByLights[4], priorityByLights[5]);
        printf("\n green   :%d,%d,%d,%d,%d,%d",
               isLightGreen[0], isLightGreen[1], isLightGreen[2],
               isLightGreen[3], isLightGreen[4], isLightGreen[5]);
        printf("\n requests:%d,%d,%d,%d,%d,%d",
               isLightRequested[0], isLightRequested[1], isLightRequested[2],
               isLightRequested[3], isLightRequested[4], isLightRequested[5]);
        printf("\n");

        lightChan ? quota;
        isLightRequested[id-1] = true;

        // Если светофор был зеленый, то мы делаем его красным и уменьшаем приоритет
        if
        :: isLightGreen[id-1] ->
                priorityByLights[id-1] = 0;
                isLightGreen[id-1] = false
        :: else -> skip
        fi;

        if
        :: priorityByLights[id-1] > 0 ->
                // Определяем текущий максимальный приоритет
                curPriority  = priorityByLights[id-1];
                maxPriority = 0;
                idx = 0;
                do
                :: idx < MAX_INTERSECT_NUM ->
                        lightIdx = conflicts[id-1].c[idx];
                        if
                        :: lightIdx != 0 && priorityByLights[lightIdx-1] > maxPriority ->
                                maxPriority = priorityByLights[lightIdx-1]
                        :: else -> skip
                        fi;
                        idx++
                :: else -> break
                od;

                if
                // Делаем светофор зеленым, если текущий максимальный приоритет = 0
                :: maxPriority == 0 ->
                        isLightGreen[id-1] = true;
                        isLightRequested[id-1]    = false;
                        priorityByLights[id-1] = MAX_PRIORITY_INCREASE + id
                // Если у другой дороги больше приоритет, то не забираем ресурс. Увеличиваем приоритет
                :: maxPriority > curPriority ->
                        priorityByLights[id-1] = curPriority + DEF_PRIORITY_INCREASE;
                        idx = 0;
                        do
                        :: idx < MAX_INTERSECT_NUM ->
                                lightIdx = conflicts[id-1].c[idx];
                                if
                                :: lightIdx != 0 ->
                                        priorityByLights[lightIdx-1] = priorityByLights[lightIdx-1] + DEF_PRIORITY_INCREASE
                                :: else -> skip
                                fi;
                                idx++
                        :: else -> break
                        od
                :: else ->
                // Если у нас самый высокий приоритет, то захватываем ресурс
                        isLightGreen[id-1] = true;
                        isLightRequested[id-1]    = false;
                        priorityByLights[id-1] = MAX_PRIORITY_INCREASE + id
                fi;
                // Передаем токен дальше
                activeLight = nextLight
        :: else ->
                // Если у нас нулевой приоритет, значит мы недавно захватывали ресурс
                // Ставим дефолтный приоритет, передаем токен дальше
                if
                :: isLightRequested[id-1] ->
                        priorityByLights[id-1] = id
                :: else -> skip
                fi;
                activeLight = nextLight
        fi
    od
}

proctype Generator(chan lc1, lc2, lc3, lc4, lc5, lc6)
{
    do
    :: lc1!1 
    :: lc2!1 
    :: lc3!1 
    :: lc4!1 
    :: lc5!1 
    :: lc6!1
    od
}

init {
    chan lightChan1 = [1] of { byte };
    chan lightChan2 = [1] of { byte };
    chan lightChan3 = [1] of { byte };
    chan lightChan4 = [1] of { byte };
    chan lightChan5 = [1] of { byte };
    chan lightChan6 = [1] of { byte };

    conflicts[0].c[0]=3; conflicts[0].c[1]=4; conflicts[0].c[2]=2; conflicts[0].c[3]=0;
    conflicts[1].c[0]=3; conflicts[1].c[1]=4; conflicts[1].c[2]=1; conflicts[1].c[3]=6;
    conflicts[2].c[0]=2; conflicts[2].c[1]=1; conflicts[2].c[2]=0; conflicts[2].c[3]=0;
    conflicts[3].c[0]=2; conflicts[3].c[1]=1; conflicts[3].c[2]=5; conflicts[3].c[3]=6;
    conflicts[4].c[0]=6; conflicts[4].c[1]=4; conflicts[4].c[2]=0; conflicts[4].c[3]=0;
    conflicts[5].c[0]=2; conflicts[5].c[1]=5; conflicts[5].c[2]=4; conflicts[5].c[3]=0;

    run Light(1, 2, lightChan1);
    run Light(2, 3, lightChan2);
    run Light(3, 4, lightChan3);
    run Light(4, 5, lightChan4);
    run Light(5, 6, lightChan5);
    run Light(6, 1, lightChan6);

    run Generator(lightChan1, lightChan2, lightChan3, lightChan4, lightChan5, lightChan6)
}


// Safety
// 1x -- EW(2) x NS(3)
// spin -search -bfs  -ltl p1 light.pml
ltl p1 { [](!(isLightGreen[1] && isLightGreen[2])) }

// 2x -- EW(2) x NE(4) 
// spin -search -bfs  -ltl p2 light.pml
ltl p2 { [](!(isLightGreen[1] && isLightGreen[3])) }

// 3x -- EW(2) x WN(1)
// spin -search -bfs  -ltl p3 light.pml
ltl p3 { [](!(isLightGreen[1] && isLightGreen[0])) }

// 4x -- WN(1) x NS(3)
// spin -search -bfs  -ltl p4 light.pml
ltl p4 { [](!(isLightGreen[0] && isLightGreen[2])) }

// 5x -- WN(1) x NE(4)
// spin -search -bfs  -ltl p5 light.pml
ltl p5 { [](!(isLightGreen[0] && isLightGreen[3])) }

// 6x -- NE(4) x ES(5)
// spin -search -bfs  -ltl p6 light.pml
ltl p6 { [](!(isLightGreen[3] && isLightGreen[4])) }

// 7x -- EW(2) x PD(6)
// spin -search -bfs  -ltl p7 light.pml
ltl p7 { [](!(isLightGreen[1] && isLightGreen[5])) }

// 8x -- ES(5) x PD(6)
// spin -search -bfs  -ltl p8 light.pml
ltl p8 { [](!(isLightGreen[4] && isLightGreen[5])) }

// 9x -- NE(4) x PD(6) 
// spin -search -bfs  -ltl p9 light.pml
ltl p9 { [](!(isLightGreen[3] && isLightGreen[5])) }


// Liveness 
// WN(1)
// spin -search -bfs  -ltl p10 light.pml
ltl p10 { []( (isLightRequested[0] && !isLightGreen[0]) -> (<>(isLightGreen[0])) ) }

// EW(2)
// spin -search -bfs  -ltl p11 light.pml
ltl p11 { []( (isLightRequested[1] && !isLightGreen[1]) -> (<>isLightGreen[1]) ) }

// NS(3)
// spin -search -bfs  -ltl p12 light.pml
ltl p12 { []( (isLightRequested[2] && !isLightGreen[2]) -> (<>isLightGreen[2]) ) }

// NE(4)
// spin -search -bfs  -ltl p13 light.pml
ltl p13 { []( (isLightRequested[3] && !isLightGreen[3]) -> (<>isLightGreen[3]) ) }

// ES(5)
// spin -search -bfs  -ltl p14 light.pml
ltl p14 { []( (isLightRequested[4] && !isLightGreen[4]) -> (<>isLightGreen[4]) ) }

// PD(6)
// spin -search -bfs  -ltl p15 light.pml
ltl p15 { []( (isLightRequested[5] && !isLightGreen[5]) -> (<>isLightGreen[5]) ) }


// Fairness
// WN(1)
// spin -search -bfs  -ltl p16 light.pml
ltl p16 { [](<>(!isLightGreen[0])) }

// EW(2)
// spin -search -bfs  -ltl p17 light.pml
ltl p17 { [](<>(!isLightGreen[1])) }

// NS(3)
// spin -search -bfs  -ltl p18 light.pml
ltl p18 { [](<>(!isLightGreen[2])) }

// NE(4)
// spin -search -bfs  -ltl p19 light.pml
ltl p19 { [](<>(!isLightGreen[3])) }

// ES(5)
// spin -search -bfs  -ltl p20 light.pml
ltl p20 { [](<>(!isLightGreen[4])) }

// PD(6)
// spin -search -bfs  -ltl p21 light.pml
ltl p21 { [](<>(!isLightGreen[5])) }
