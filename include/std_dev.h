//
// Created by simone on 12/08/19.
//

#ifndef UNTITLED_STD_DEV_H
#define UNTITLED_STD_DEV_H


class std_dev {
    /*
     * Class to calculate standard deviation of unkown values set
     */
    int n;
    double mu;
    double q;

    public:
        std_dev();
        ~std_dev();
        
        void new_val(double val);
        double get();
};


#endif //UNTITLED_STD_DEV_H
