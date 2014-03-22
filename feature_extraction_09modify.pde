//feature_extraction_09modify
//現段階での完成形(13/9/9)。
//手首検出('t'キー)、指検出('y'キー)、穴検出('l'キー)、認識処理('r'キー)の全てを確認できる。識をしたい

import processing.video.*;
import java.util.*;
import java.text.*;


Capture CAMERA;     //Captureオブジェクトの変数
PImage FIL_CAMERA;  //処理後のカメラ画像を保存する変数
PImage Quants;      //量子化したFIL_CAMERAを保存する変数
PImage Median;      //メディアンフィルタのための変数 nakahodo
PImage Result;      //輪郭抽出したQuantsを保存する変数


int H_MAX = 360;    //色相値の最大値
int S_MAX = 100;    //彩度値の最大値
int B_MAX = 100;    //輝度値の最大値

int CAM_W = 320;    //カメラの取得画像幅
int CAM_H = 240;    //カメラの取得画像高さ

int FRAMERATE = 30;     //カメラと画面のフレームレート

int HUE_TH_MIN = 300;   //色相値の下限閾値
int HUE_TH_MAX = 55;    //色相値の上限閾値

int SATU_TH_MIN = 0;    //彩度値の下限閾値
int SATU_TH_MAX = 100;  //彩度値の上限閾値

int BRI_TH_MIN = 0;     //明度の下限閾値
int BRI_TH_MAX = 99;    //明度の上限閾値

boolean mflag = false;  // メディアンフィルタをかけるかのフラグ nakahodo
boolean yflag = false; //指認識
boolean lflag = false; //labelling
boolean tflag = false; //sikaku, grav, tekubi
boolean rflag = false; //認識開始
boolean togire_flag = true;//輪郭線を周回するときに途切れたかどうかのフラグ

boolean pflag = false;//debug

int grav_x, grav_y; //重心座標
int grav_count;//白ピクセルの数
int black_pix;//四角形内の背景（黒）ピクセルの数
int squ_x1, squ_x2, squ_y1, squ_y2;  // 長方形の座標
int rinkaku_pix; //輪郭線のピクセル数をカウント

int position;//手首の位置（up=1, left=2, down=3, unknown=0）とする。
int ana;//穴の有無（有りana=1, 無しana=0）とする。
int finger;//指の本数（０〜５本)とする。


void setup() {

  //ウィンドウの作成．今回は4つの画像を見るために縦横2倍に設定
  size(CAM_W * 3, CAM_H * 2);

  //カラーモードの設定
  colorMode(HSB, H_MAX, S_MAX, B_MAX);
  //println(Capture.list());
  CAMERA = new Capture(this, CAM_W, CAM_H, FRAMERATE);     //Captureオブジェクトの生成
  // カメラを変えるときにはこれを使う。
  //CAMERA = new Capture(this, CAM_W, CAM_H, Capture.list()[1], FRAMERATE);

  FIL_CAMERA = new PImage(CAM_W, CAM_H);      //FIL_CAMERAの初期化
  Quants = new PImage(CAM_W, CAM_H);          //Quantsの初期化
  Result = new PImage(CAM_W, CAM_H);          //Resultの初期化

  //画面のフレームレートの設定
  frameRate(FRAMERATE);
  CAMERA.start();
}

void draw() {

  //処理時間を計測する
  long start = System.currentTimeMillis();
  //long start = System.nanoTime();

  image(CAMERA, 0, 0);//画面の左半分にカメラの画像を表示
  ////////////////////////////////////////////////////////////////////
  ///取得画像から肌色のピクセルを抽出////////////////////////////////
  FIL_CAMERA = Hada(CAMERA);
  FIL_CAMERA.updatePixels(); //FIL_CAMERAのアップデート
  //image(FIL_CAMERA, CAM_W, CAM_H);     //画面の右半分にFIL_CAMERAを表示
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  ///2値化//////////////////////////////////////////////////////////
  Niti(FIL_CAMERA);
  Quants.updatePixels();
  image(Quants, CAM_W, 0);
  //////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////
  /// メディアンフィルタ nakahodo //////////////////////////////////
  if ( mflag == true ) {
    Quants = medianfilter(Quants);
    Quants.updatePixels();
    image(Quants, CAM_W, 0);
  }
  /////////////////////////////////////////////////////////////////

  ///////////////closing////////////////////////////////////////////
  for (int i=0; i<3; i++) {
    Quants = contraction(Quants);
  }
  for (int i=0; i<3; i++) {
    Quants = expansion(Quants);
  }
  Quants.updatePixels();
  image(Quants, CAM_W*2, 0);
  //////////////////////////////////////////////////////////////////

  ////////前処理のラベリング//////////////////////////////////////////
  Quants = Pre_Label(Quants);
  Quants.updatePixels();
  image(Quants, 0, CAM_H);
  /////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  /////// 周囲(4ピクセル)の平均値と比較する(ラプラシアンフィルタ)//
  Rapu(Quants);
  Result.updatePixels();    //Resultのデータを更新
  //image(Result, 0, CAM_H);    //Resultをx=CAM_W,y=CAM_Hに出力
  /////////////////////////////////////////////////////////////////

  //////////////////下部の端と端をつなげる///////////////////
  hasi();
  Result.updatePixels();//輪郭線の画像に上書きする。
  //image(Result, 0, CAM_H);
  /////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  if ( tflag == true) {
    /////四角で囲う/////////////////////////////////////////////////
    //Sikaku(Mozaiku);//長方形作成  
    Sikaku(Quants);
    ////////////////////////////////////////////////////////////////
    grav(Quants);
    //////手首方向の推定//////////////////////////////////////////////
    position = 0;
    position = tekubi(Quants); //(position)手首の位置（up=1, left=2, down=3, unknown=0）とする。
    //////四角形内の背景（黒）ピクセルの数をカウント(black_pix)/////
    BLcount();
    ///////////////////////
  }
  ////////////////////////////////////////////////////////////////

  ////////yubi recogunition/////////
  if ( yflag == true) {
    finger = 6;
    boolean rinkaku_flag = false;//輪郭線を探索するフラグ。輪郭線を発見したら"true"にする。

    try {
      for (int i= grav_y*CAM_W + grav_x-1 ; i>=grav_y*CAM_W+1; i--) {//重心点から左に向かって輪郭線を探索する。
        if (brightness(Result.pixels[i]) == 100) {  //明度100なら輪郭線
          finger =  Yubi(Result, i); //指の本数(0〜5、unknownなら6)が返ってくる。Yubi(輪郭線画像,  重心点の座標)
          if (finger != 6) { //指の本数が確定しているか？（6ならunknown）
            rinkaku_flag = true; //輪郭線を発見している
          }
          break; //forのループから抜ける
        }
      }

      if (rinkaku_flag = false) { //上の処理で輪郭線を見つけられなかった場合
        for (int i= squ_y1*CAM_W + squ_x1+1 ; i<squ_y1*CAM_W+CAM_W; i++) { //手領域の四角形の左上角から右に向かって輪郭線を探索する。
          if (brightness(Result.pixels[i]) == 100) { //明度100なら輪郭線
            finger = Yubi(Result, i); //指の本数(1〜5、unknownなら6)が返ってくる。Yubi(輪郭線画像,  重心点の座標)
            if (finger != 6) { //指の本数が確定しているか？（6ならunknown）
              rinkaku_flag = true; //輪郭線を発見している
            }
            break;//forのループから抜ける
          }
        }
      }

      if (rinkaku_flag = false) {
        for (int i = grav_y*CAM_W + grav_x; i>=grav_x; i-=CAM_W) {
          if (brightness(Result.pixels[i]) == 100) { //明度100なら輪郭線
            finger = Yubi(Result, i); //指の本数(1〜5、unknownなら6)が返ってくる。Yubi(輪郭線画像,  重心点の座標)
            if (finger != 6) { //指の本数が確定しているか？（6ならunknown）
              rinkaku_flag = true; //輪郭線を発見している
            }
            break;//forのループから抜ける
          }
        }
      }
    }
    catch(ArrayIndexOutOfBoundsException e ) { //例外処理
      println("Yubi method : " + e + "grav_x = " + grav_x + ", grav_y = " + grav_y + ", grav_count = " + grav_count);
    }
  }
  ///////////////////////////////////////////

  ///////////////labelling(輪（穴）の検出)////////////////////
  if ( lflag == true) {
    ana = 0;
    ana = Label(Quants);
  }
  ///////////////////////////////////////////

  //////////Recognittion//////////////////////
  if (rflag == true) {
    if (togire_flag == false  &&  position != 0  &&  finger != 6) {//輪郭線の途切れの有無、手首の位置がちゃんと検出できていれば認識開始
      Recognition();
    }
  }
  //////////////////////////////////////////
  //処理時間を計測する
  long stop = System.currentTimeMillis();
  //long stop =  System.nanoTime();
  //println("Time = " + (stop - start) + "nsec");
}//void draw()の終わり



//新たに定義した関数
/////////////////////////////////////////////////////////////////
///肌色抽出//////////////////////////////////////////////////////
PImage Hada(PImage hada) {
  //カメラの撮った画像のピクセルをひとつづつチェックする
  for (int i =0; i<CAM_W*CAM_H;i++) {
    //チェックするピクセルのカラー
    color cc = hada.pixels[i];
    //フィルタ処理
    ///チェックするピクセルのカラーが
    //条件に合致した場合そのピクセルのカラーをFIL_CAMERAの該当ピクセルに代入
    //非合致なら黒をFIL_CAMERAの該当ピクセルに代入する
    if (usr_serchcolor(cc) && usr_serchcolor_satu(cc) && usr_serchcolor_bri(cc)) {
      FIL_CAMERA.pixels[i] = hada.pixels[i];
    }
    else { 
      FIL_CAMERA.pixels[i] = color(0);
    }
  }
  return FIL_CAMERA;
}
///肌色抽出ここまで///////////////////////////////////////////////

/////////////////////////////////////////////////////////////////
///色相（H)の判定////////////////////////////////////////////////

//カラー引数の色相が下限閾値以上,上限閾値未満かどうかの判定
boolean usr_serchcolor(color x) {
  if (HUE_TH_MIN <= HUE_TH_MAX) {
    if (HUE_TH_MIN <= hue(x) && hue(x) < HUE_TH_MAX) {
      return true;
    }
    else {
      return false;
    }
  }
  else {
    //閾値が 下限値 > 上限値のときは
    //色相環のループを考える
    if (HUE_TH_MAX <= hue(x) && hue(x) < HUE_TH_MIN) {
      return false;
    }
    else {
      return true;
    }
  }
}
///色相（H)の判定ここまで///////////////////////////////////////

/////////////////////////////////////////////////////////////////
///彩度（S)の判定///////////////////////////////////////////////

//カラー引数の彩度が下限閾値以上,上限閾値未満かどうかの判定
boolean usr_serchcolor_satu(color x) {
  if (SATU_TH_MIN <= saturation(x) && saturation(x) < SATU_TH_MAX) {
    return true;
  }
  else {
    return false;
  }
}
///彩度（S)の判定ここまで////////////////////////////////////////

/////////////////////////////////////////////////////////////////
///明度（B)判定//////////////////////////////////////////////////

//カラー引数の明度が下限閾値以上,上限閾値未満かどうかの判定
boolean usr_serchcolor_bri(color x) {
  if (BRI_TH_MIN <= brightness(x) && brightness(x) <= BRI_TH_MAX) {
    return true;
  }
  else {
    return false;
  }
}
///明度（B）の判定ここまで///////////////////////////////////////

//////////////////////////////////////////////////////
//////二値化（輝度＞０)//////////////////////////////////
void Niti(PImage FIL) {
  for ( int i=0; i<CAM_W*CAM_H; i++) {
    if ( brightness(FIL.pixels[i]) > 0) {
      Quants.pixels[i] = color(360);
    }
    else {
      Quants.pixels[i] = color(0);
    }
  }
}
////////////////////////////////////////////////////

////////////////////////////////////////////////////
/////// メディアンフィルタ（中央値フィルタ) nakahodo/////////////

PImage medianfilter( PImage MMM ) {
  color[] pixarray = new color[9];

  for (int y=1; y<CAM_H-1; y++) {
    for (int x=1; x<CAM_W-1; x++) {
      int i = y*CAM_W + x;
      // 周囲9ピクセルをArrayに格納
      pixarray[0] = MMM.pixels[i-CAM_W-1]; 
      pixarray[1] = MMM.pixels[i-CAM_W]; 
      pixarray[2] = MMM.pixels[i-CAM_W+1];
      pixarray[3] = MMM.pixels[i-1];       
      pixarray[4] = MMM.pixels[i];       
      pixarray[5] = MMM.pixels[i+1];
      pixarray[6] = MMM.pixels[i+CAM_W-1]; 
      pixarray[7] = MMM.pixels[i+CAM_W]; 
      pixarray[8] = MMM.pixels[i+CAM_W+1];

      // Sortを行う
      pixarray = sort(pixarray);

      // 中央値を採用する
      Quants.pixels[i] = pixarray[4];
    }
  }
  pixarray = null;

  return Quants;
}
/////// メディアンフィルタここまで　nakahodo /////////////////////

////////////////////////////////////////////////////
/////////////expansion//////////////////////////////////////////////
PImage expansion(PImage FIL) {
  PImage EXPAND = new PImage(CAM_W, CAM_H);
  for (int y=1; y<CAM_H-1; y++) {
    for (int x=1; x<CAM_W-1; x++) {
      int i = y*CAM_W + x;
      if (brightness(FIL.pixels[i-CAM_W-1]) > 0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i-CAM_W]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i-CAM_W+1]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i-1]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i+1]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i+CAM_W-1]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i+CAM_W]) >0)
        EXPAND.pixels[i] = color(360);
      else if (brightness(FIL.pixels[i+CAM_W+1]) >0)
        EXPAND.pixels[i] = color(360);
    }
  }
  return EXPAND;
}
//////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
/////////////contraction//////////////////////////////////////////////
PImage contraction(PImage FIL) {
  PImage CONTRACT = new PImage(CAM_W, CAM_H);
  for (int y=1; y<CAM_H-1; y++) {
    for (int x=1; x<CAM_W-1; x++) {
      int i = y*CAM_W + x;
      if (brightness(FIL.pixels[i-CAM_W-1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i-CAM_W]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i-CAM_W+1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i-1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i+1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i+CAM_W-1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i+CAM_W]) == 0)
        CONTRACT.pixels[i] = color(0);
      else if (brightness(FIL.pixels[i+CAM_W+1]) == 0)
        CONTRACT.pixels[i] = color(0);
      else
        CONTRACT.pixels[i] = color(360);
    }
  }
  return CONTRACT;
}
//////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
////ラベリング（前処理）/////////////////////////////////
PImage Pre_Label(PImage FIL) {  //FIL・・・ラベリングしたい画像PImageをもらう
  PImage LABE = new PImage(CAM_W, CAM_H);
  int[][] label_eria = new int[CAM_H + 1][CAM_W + 2];    //作業領域の確保。走査を画像の原点から始めるため
  int P = 1;    //ラベルのカウントをするための変数
  int[] Dst = new int[100];  //ラベリングのラベルをきれいに並べるための配列
  for (int x=0; x<Dst.length; x++) {  //ラベルのグループ配列の初期化（配列に数字１〜１００を代入）
    Dst[x] = x;
  }
  //注目している配列の周りの配列
  //　（左上）｜（上）　｜（右上）
  //  （左）  ｜（注目）｜
  try {
    for (int y=1; y<=CAM_H; y++) {   //画像（作業領域の上下左右1マス少ない領域）の走査。　配列のサイズ（label_eria[][]）を考慮している
      for (int x=1; x<=CAM_W; x++) {
        if (brightness(FIL.pixels[(y-1)*CAM_W + (x-1)]) == 100) {  //白いピクセルの発見

          if (label_eria[y][x-1] != 0) {  //（左）のラベルが0じゃないとき
            label_eria[y][x] = label_eria[y][x-1];  //（左）のラベルを（注目）に格納
            if (label_eria[y-1][x-1] != 0  &&  label_eria[y-1][x-1] != label_eria[y][x]) {  //（左上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x-1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x-1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、小さい方のラベルを（左上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する（説明が難しい）
                Dst[label_eria[y-1][x-1]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x] != 0    &&  label_eria[y-1][x] != label_eria[y][x]) {  //（上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x], label_eria[y][x]);  //小さいラベルを（注目）に格納

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) { //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に格納

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは

                Dst[label_eria[y-1][x+1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）のラベルが0じゃないとき＿終わり

          else if (label_eria[y-1][x-1] != 0) {//（左）のラベルが0のときかつ（左上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x-1];  //（左上）のラベルを（注目）に代入
            if (label_eria[y-1][x] != 0    &&  label_eria[y-1][x] != label_eria[y][x]) {  //（上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) {  //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] != label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x+1]] = label_eria[y][x];   //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）のラベルが0のときかつ（左上）が０じゃないとき＿終わり

          else if ( label_eria[y-1][x] != 0) {//（左）と（左上）が０のときかつ（上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x];  //（上）のラベルを（注目）に代入
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) {  //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x+1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）と（左上）が０のときかつ（上）が０じゃないとき＿終わり

          else if (label_eria[y-1][x+1] != 0) {//（左）と（左上）と（上）が０のときかつ（右上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x+1];  //（右上）のラベルを（注目）に代入

            if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
              Dst[label_eria[y-1][x+1]] = label_eria[y][x];   //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
            }
            else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
              Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
            }
          }//（左）と（左上）と（上）が０のときかつ（右上）が０じゃないとき＿終わり

          else { 
            label_eria[y][x] = P;  //周りのラベルをもったピクセルが存在しないので新しいラベルを格納
            P++;    //次のラベルを格納する準備
          }
        }//白いピクセルの発見＿終わり
      }//for(x)end
    }//for(y)end

    P = P-1;    //デバッグ用。白背景の数と配列とラベルを表示
    //println("背景（白)の数は"+ P + "個");

    //配列の修正。Dst[]に格納されているラベルの数値を低いほうにつめていく。未完成！！！！！←修正してみた
    for (int j=0; j<8; j++) {
      for (int i=Dst.length-1; i>0; i--) {
        if ( i != Dst[i]   &&   Dst[i] != Dst[Dst[i]] ) {
          Dst[i] = Dst[Dst[i]];
        }
      }
    }

    //ラベル値の詰めなおし
    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        for (int i=0; i<Dst.length; i++) {
          if  (i != Dst[i]  &&  label_eria[y][x] == i) {
            label_eria[y][x] = Dst[i];
            break;
          }
        }
      }
    }

    //面積が大きい部分を取り出す
    //はじめに、各ラベルごとの面積（ピクセル数）をカウントしていく。
    int[] labelling = new int[P+1];//ラベルが０のとき、配列エラーがでるので、とりあえず１つ多めに配列を定義しておく。
    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        labelling[label_eria[y][x]]++;//label_eria[][]内の各ラベルをカウント。
      }
    }
    //最も面積(ピクセル数)が大きいラベル値をさがす。
    int max_label = 1;//ラベル１をとりあえず最大としておく。
    for (int i=2; i<P; i++) {
      if ( labelling[max_label] < labelling[i]) {//各ラベルの面積（ピクセル数）を比較していく。
        max_label = i;
      }
    }
    //最も大きいラベルの部分だけを新しいPImage（LABE）に入れていく。
    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        if ( label_eria[y][x] == max_label) {
          LABE.pixels[y*CAM_W + x] = color(360);
        }
      }
    }
  }
  catch(ArrayIndexOutOfBoundsException e) {
    println("pre_labelling : " + e);
  }

  return LABE;
  //デバッグ用画像ここまで
}//labelここまで

////ラベリングここまで//////////////////////////


/////ラプラシアンフィルタ/////////////////////////////////////////
void Rapu(PImage FIL) {
  for (int y=1; y<CAM_H-1; y++) {
    for (int x=1; x<CAM_W-1; x++) {
      int i = y*CAM_W + x;
      //aroundに注目しているピクセルの周囲のピクセルの平均値を代入
      float around = ( brightness(FIL.pixels[i-CAM_W])
        + brightness(FIL.pixels[i-1])
        + brightness(FIL.pixels[i+1])
        + brightness(FIL.pixels[i+CAM_W]))/4;
      if (around < brightness(FIL.pixels[i])) {
        Result.pixels[i] = color(360);
      } // 平均値が注目ピクセルより低ければResultの該当ピクセルに黒を代入
      else Result.pixels[i] = color(0);
    }
  }
  //return Result;
}
///ラプラシアンフィルタここまで//////////////////////////////////

/////下部の端と端をつなげる////////////////////////////////////////
void hasi() {
  for (int i=1; i<CAM_W-2; i++) {//最下線
    int x = (CAM_H-2)*CAM_W + i;
    if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+1])==0) {
      Result.pixels[x+1] = color(360);
    }
    else if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+1])==100) {
      break;
    }
  }

  for (int i=1; i<CAM_W-2; i++) {//最上線部
    int x = i + CAM_W;
    if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+1])==0) {
      Result.pixels[x+1] = color(360);
    }
    else if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+1])==100) {
      break;
    }
  }

  for (int i=1; i<CAM_H-2; i++) {//最左線部
    int x = CAM_W * i + 1; 
    if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+CAM_W])==0) {
      Result.pixels[x+CAM_W] = color(360);
    }
    else if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+CAM_W])==100) {
      break;
    }
  }

  for (int i=1; i<CAM_H-2; i++) { //最右線部
    int x = CAM_W * i + CAM_W-2;
    if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+CAM_W])==0) {
      Result.pixels[x+CAM_W] = color(360);
    }
    else if (brightness(Result.pixels[x])==100 && brightness(Result.pixels[x+CAM_W])==100) {
      break;
    }
  }
}
/////////////////////////////////////////////////////////////////



//////重心設置//////////////////////////////////////////////////
void grav(PImage gazou) {
  grav_count=0 ;
  grav_x=0;
  grav_y=0;
  for ( int i = 0; i < CAM_W * CAM_H; i++) {
    // 白ピクセルの座標をすべて足して、その平均を出すという手法
    if ( brightness(gazou.pixels[i]) == 100) {
      grav_x +=  i%CAM_W; // x座標を足す
      grav_y +=  i/CAM_W; // y座標を足す
      grav_count++;       // 個数を足す
    }
  }
  if (grav_count != 0) {
    grav_x = grav_x / grav_count;
    grav_y = grav_y / grav_count;
  }
  // 円の描画
  fill(0, 100, 100); // 塗りつぶす色 赤(HSV)
  stroke(0, 100, 100);// 線の色 赤(HSV)
  ellipse( grav_x, grav_y+CAM_H, 10, 10); // に表示されていることが前提
}
// 重心設置テスト　ここまで      //
////////////////////////////////////////////////////////////////


///長方形作成////////////////////////////////////////////////////
void Sikaku(PImage SIKAKU) {
  squ_x1=0;
  squ_x2=100;
  squ_y1=0;
  squ_y2=100;  // 長方形の座標
  // y1のサーチ
  for ( int i = 0; i < CAM_W * CAM_H; i++) {
    // 最初に出てくる白ピクセルの座標を検出し、代入
    if ( brightness(SIKAKU.pixels[i]) == 100) {
      //squ_x1 =  i%CAM_W; // x座標を代入
      squ_y1 =  i/CAM_W; // y座標を代入
      break;              // for文から抜ける
    }
  }

  // x1のサーチ
  // 縦に数える
  int flag_x1= 0; // 二重ループを抜けるためのフラグ
  for (int x=0; x<CAM_W; x++) {
    for (int pos=x; pos<CAM_W * CAM_H; pos=pos+CAM_W) {
      if ( brightness(SIKAKU.pixels[pos]) == 100) {
        squ_x1 =  pos%CAM_W; // x座標を代入
        flag_x1=1; 
        break;    // for文から抜ける
      }
    }
    if ( flag_x1 == 1) { 
      break;
    } // for文から抜ける
  } 

  // y2のサーチ
  // 最後から数えていく
  for ( int i = CAM_W * CAM_H-1; i >= 0; i--) {
    // 最後に出てくる白ピクセルの座標を検出し、代入
    if ( brightness(SIKAKU.pixels[i]) == 100) {
      //squ_x2 =  i%CAM_W; // x座標を代入
      squ_y2 =  i/CAM_W; // y座標を代入
      break;              // for文から抜ける
    }
  }

  // x2のサーチ
  // 縦に数える 最後から数える
  int flag_x2= 0; // 二重ループを抜けるためのフラグ
  for (int x=0; x<CAM_W; x++) {
    for (int pos=CAM_W * CAM_H-1-x; pos>x; pos=pos-CAM_W) {
      if ( brightness(SIKAKU.pixels[pos]) == 100) {
        squ_x2 =  pos%CAM_W; // x座標を代入
        flag_x2=1; 
        break;    // for文から抜ける
      }
    }
    if ( flag_x2 == 1) { 
      break;
    } // for文から抜ける
  }
  stroke(255, 100, 100); // 四角の色。(HSV)
  noFill();          // 塗りつぶさない
  rectMode(CORNERS); // 四角形の作り方　座標指定モード
  rect(squ_x1, squ_y1+CAM_H, squ_x2, squ_y2+CAM_H); //に表示
}
///////長方形ここまで////////////////////////////////////////////


///手首方向の推定///////////////////////////////////////////////
int tekubi(PImage gazou) {
  //基準軸の判断（縦長か横長かの判断）
  int posi=0;//手首の位置（up=1, left=2, down=3, unknown=0）とする。
  int x_length = squ_x2 - squ_x1;   //四角形の横の長さ
  int y_length = squ_y2 - squ_y1;  //四角形の縦の長さ
  int L1=0, L2=0;   //走査線のｙ座標（s1が上側、s2が下側）
  int S1=0, S2=0, SG=0;  //走査線上にある白ピクセルの数  
  if (x_length >= y_length) {  //横の方が長ければ手首は左側にある
    //println("左");
    posi = 2;//手首の位置（up=1, left=2, down=3, unknown=0）とする。
  }
  else {
    int m = grav_y - squ_y1;  //重心から最上位の白ピクセルまでの長さ
    int n = squ_y2 - grav_y;  //重心から最下位の白ピクセルまでの長さ
    if (m >= n) {    //長いほうの走査線を浅く、短い方の走査線を深くする 
      L1 = squ_y1 + n/8;  
      L2 = squ_y2 - m/8;
    }
    else {
      L1 = squ_y1 + m/8;
      L2 = squ_y2 - n/8;
    }
    stroke(120, 100, 100);  //緑の線を表示
    line(squ_x1, L1+CAM_H, squ_x2, L1+CAM_H);  //に表示することを前提(指側の線)
    stroke(0, 100, 100);
    line(squ_x1, L2+CAM_H, squ_x2, L2+CAM_H);  //に表示することを前提(手首側の線)

    try {
      for (int x=1; x<CAM_W-1; x++) {  //走査線上にあるピクセルを探す
        if ( brightness(gazou.pixels[L1*CAM_W + x]) == 100) {
          S1++;
        }  //走査線上で白ピクセルならS1にプラス１
        if ( brightness(gazou.pixels[grav_y*CAM_W + x]) == 100) {
          SG++;
        }  //走査線上で白ピクセルならSGにプラス１
        if ( brightness(gazou.pixels[L2*CAM_W + x]) == 100) {
          S2++;
        }  //走査線上で白ピクセルならS2にプラス１
      }
    }
    catch(ArrayIndexOutOfBoundsException e) {
      println("error : " + e);
    }


    if (SG>S2 && S2>S1 || S1>SG && SG>S2) {
      //println("下");
      posi = 3;//手首の位置（up=1, left=2, down=3, unknown=0）とする。
    }
    else if (SG>S1 && S1>S2 || S2>SG && SG>S1) {
      //println("上");
      posi = 1;//手首の位置（up=1, left=2, down=3, unknown=0）とする。
    }
    else {
      println("position unknown");
      posi = 1;
    }
  }
  return posi;
}//tekubiここまで
//////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
/////////////BLcount///////
void BLcount() {
  black_pix=0;
  black_pix = (squ_x2-squ_x1)*(squ_y2-squ_y1) - grav_count;
}
/////////////BLcount end /////////////////////////////////////

////////////////////////////////////////////////////
////ラベリング（背景の数を数えたい）/////////////////////////////////
int Label(PImage FIL) {  //FIL・・・ラベリングしたい画像PImageをもらう
  PImage FIL_LABE = new PImage(CAM_W, CAM_H);//表示用のPImageオブジェクト
  int ANA=0;//穴の有無（有りana=1, 無しana=0）とする。
  int[][] label_eria = new int[CAM_H + 1][CAM_W + 2];    //作業領域の確保。走査を画像の原点から始めるため
  int P = 1;    //ラベルのカウントをするための変数
  int[] Dst = new int[100];  //ラベリングのラベルをきれいに並べるための配列
  for (int x=0; x<Dst.length; x++) {  //ラベルのグループ化配列
    Dst[x] = x;
  }
  //注目している配列の周りの配列
  //　（左上）｜（上）　｜（右上）
  //  （左）  ｜（注目）｜
  try {
    for (int y=1; y<=CAM_H; y++) {   //画像（作業領域の上下左右1マス少ない領域）の走査。　配列のサイズ（label_eria[][]）を考慮している
      for (int x=1; x<=CAM_W; x++) {
        if (brightness(FIL.pixels[(y-1)*CAM_W + (x-1)]) == 0) {  //黒いピクセルの発見

          if (label_eria[y][x-1] != 0) {  //（左）のラベルが0じゃないとき
            label_eria[y][x] = label_eria[y][x-1];  //（左）のラベルを（注目）に格納
            if (label_eria[y-1][x-1] != 0  &&  label_eria[y-1][x-1] != label_eria[y][x]) {  //（左上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x-1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x-1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、小さい方のラベルを（左上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する（説明が難しい）
                Dst[label_eria[y-1][x-1]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x] != 0    &&  label_eria[y-1][x] != label_eria[y][x]) {  //（上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x], label_eria[y][x]);  //小さいラベルを（注目）に格納

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) { //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に格納

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは

                Dst[label_eria[y-1][x+1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）のラベルが0じゃないとき＿終わり

          else if (label_eria[y-1][x-1] != 0) {//（左）のラベルが0のときかつ（左上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x-1];  //（左上）のラベルを（注目）に代入
            if (label_eria[y-1][x] != 0    &&  label_eria[y-1][x] != label_eria[y][x]) {  //（上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x]] = Dst[label_eria[y][x]];
              }
            }
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) {  //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] != label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x+1]] = label_eria[y][x];   //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）のラベルが0のときかつ（左上）が０じゃないとき＿終わり

          else if ( label_eria[y-1][x] != 0) {//（左）と（左上）が０のときかつ（上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x];  //（上）のラベルを（注目）に代入
            if (label_eria[y-1][x+1] != 0    &&  label_eria[y-1][x+1] != label_eria[y][x]) {  //（右上）のラベルが０じゃないかつ（注目）と違う値なら
              label_eria[y][x] = min(label_eria[y-1][x+1], label_eria[y][x]);  //小さいラベルを（注目）に代入

              if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
                Dst[label_eria[y-1][x+1]] = label_eria[y][x];  //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
              }
              else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
                Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
              }
            }
          }//（左）と（左上）が０のときかつ（上）が０じゃないとき＿終わり

          else if (label_eria[y-1][x+1] != 0) {//（左）と（左上）と（上）が０のときかつ（右上）が０じゃないとき
            label_eria[y][x] = label_eria[y-1][x+1];  //（右上）のラベルを（注目）に代入

            if ( Dst[ label_eria[y][x]] == label_eria[y][x]) {                 //番地（ラベルの値番地）に格納されている値と、ラベルの値が異なるとき、新しく代入するのは
              Dst[label_eria[y-1][x+1]] = label_eria[y][x];   //ラベルの値が格納先の番地数と等しければ、 小さい方のラベルを（右上）に格納されていたラベルの値（番地）に格納
            }
            else {     //ラベルの値そのままではなくて、ラベルの元をたどった値を代入する
              Dst[label_eria[y-1][x+1]] = Dst[label_eria[y][x]];
            }
          }//（左）と（左上）と（上）が０のときかつ（右上）が０じゃないとき＿終わり

          else { 
            label_eria[y][x] = P;  //周りのラベルをもったピクセルが存在しないので新しいラベルを格納
            P++;    //次のラベルを格納する準備
          }
        }//黒いピクセルの発見＿終わり
      }//for(x)end
    }//for(y)end

    P = P-1;    //デバッグ用。背景の数と配列とラベルを表示
    //println("背景（黒)の数は"+ P + "個");

    //配列の修正。Dst[]に格納されているラベルの数値を低いほうにつめていく。
    //    for (int y=1; y<=CAM_H; y++) {
    //      for (int x=1; x<=CAM_W; x++) {
    //        for (int i=0; i<Dst.length; i++) {
    //          if  (i != Dst[i]  &&  label_eria[y][x] == i) {
    //            label_eria[y][x] = Dst[i];
    //            break;
    //          }
    //        }
    //      }
    //    }

    //配列の修正。Dst[]に格納されているラベルの数値を低いほうにつめていく。未完成！！！！！←修正してみた
    for (int j=0; j<7; j++) {
      for (int i=Dst.length-1; i>0; i--) {
        if ( i != Dst[i]   &&   Dst[i] != Dst[Dst[i]] ) {
          Dst[i] = Dst[Dst[i]];
        }
      }
    }


    //ラベル値の詰めなおし
    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        for (int i=0; i<Dst.length; i++) {
          if  (i != Dst[i]  &&  label_eria[y][x] == i) {
            label_eria[y][x] = Dst[i];
            break;
          }
        }
      }
    }


    //面積が大きい部分を取り出す
    //はじめに、各ラベルごとの面積（ピクセル数）をカウントしていく。
    int[] labelling = new int[P+1];//ラベルが０のとき、配列エラーがでるので、とりあえず１つ多めに配列を定義しておく。
    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        labelling[label_eria[y][x]]++;//label_eria[][]内の各ラベルをカウント。
      }
    }
    //最も面積(ピクセル数)が大きいラベル値をさがす。
    int max_label = 1;//ラベル１をとりあえず最大としておく。
    int second_label = 2;////２番めに大きいラベル。とりあえず１としておく
    if (P >= 2) {
      for (int i=2; i<P; i++) {
        if ( labelling[max_label] < labelling[i]) {//各ラベルの面積（ピクセル数）を比較していく。
          second_label = max_label;
          max_label = i;
        }
      }
      for ( int i=3; i<P; i++) {
        if (labelling[second_label] < labelling[i]) {
          second_label = i;
        }
      }

      if ( (float)labelling[second_label]/grav_count > 0.05) {
        //println("There is a WA");
        ANA=1;//穴の有無（有りana=1, 無しana=0）とする。
      }
      //debug
      //println("labelling[second_label]/grav_count = " + (float)labelling[second_label]/grav_count);
    }

    /* println("max_label = " + max_label);
     println("second_label = " + second_label);
     println("labelling[max_label] = " + labelling[max_label]);
     println("labelling[second_label] = " + labelling[second_label]);
     */


    for (int y=1; y<=CAM_H; y++) {
      for (int x=1; x<=CAM_W; x++) {
        if (label_eria[y][x] == max_label) {
          FIL_LABE.pixels[(y-1)*CAM_W +  x-1] = color(240, 100, 100);//赤を代入
        }
        else if (label_eria[y][x] == second_label) {
          FIL_LABE.pixels[(y-1)*CAM_W + x-1] = color(150, 100, 100);
        }
        else {
          FIL_LABE.pixels[(y-1)*CAM_W +  x-1] =color(200, 0, 0);//を出力
        }
      }
    }
  }
  catch(ArrayIndexOutOfBoundsException e) {
    println("labelling : " + e);
  }
  FIL_LABE.updatePixels();
  image(FIL_LABE, CAM_W, CAM_H);

  return ANA;
  //デバッグ用画像ここまで
}//labelここまで

////ラベリングここまで//////////////////////////



////////////////////////////////////////////////////////////////

int Yubi(PImage FIL, int k) {
  int FING=6;//指の本数（０〜５本で表す。unknown=6)とする。
  rinkaku_pix = 1;////輪郭線のピクセル数をカウント(初期値を1にする)
  Vector vector = new Vector();//点を打った座標を格納する
  vector.addElement(new Integer(k));  //vectorに座標を格納

  int count = 1;//点を打つタイミングにする（２０ピクセルで点を打つ）
  int u = new Integer(vector.firstElement().toString());//最初の点の座標をuに代入
  FIL.pixels[u] = color(50);//通過した印をつける（ピクセルを赤にする）
  boolean wflag = true;//while文から抜けるためのフラグ
  togire_flag = true;//輪郭線を周回するときに途切れたかどうかのフラグ
  while (wflag == true) {
    int[] P = new int[8];
    P[5] = u -CAM_W+1;  //右上
    P[2] = u +1;        //右
    P[6] = u +CAM_W+1;  //右下
    P[3] = u +CAM_W;    //下
    P[7] = u +CAM_W-1;  //左下
    P[0] = u -1;        //左
    P[4] = u -CAM_W-1;  //左上
    P[1] = u -CAM_W;    //上


    //周囲８ピクセルの解析をしていく
    for (int i=0; i<=7; i++) {
      if ( brightness(FIL.pixels[P[i]])==100 ) {//FILの座標P[i]のピクセルが白(輝度100)かつ未通過（色相０）ならそのピクセルに遷移する
        FIL.pixels[P[i]] = color(50);//通過した印をつける
        count++;
        rinkaku_pix++;
        if (count==20) {
          //Result.pixels[P[i]] = color(180, 100, 100);
          vector.addElement(new Integer(P[i]));
          count=0;
        }
        u = P[i]; //次のピクセルに移動
        break;//for文から抜ける
      }
      else if ( rinkaku_pix>20   &&   P[i] == new Integer(vector.firstElement().toString())) {//1周して最初の点に戻ったとき
        wflag = false;//while文から抜ける
        togire_flag = false;//途切れなし
        //println("success");
      }
      else if (i==7) {//周りのピクセルに白がない、または通過した印しかないとき

        //debug
        NumberFormat form = NumberFormat.getInstance();
        form.setMaximumFractionDigits(0);
        form.setMinimumIntegerDigits(3);
        /*        for (int y=-10; y<11; y++) {
         for (int x=-10; x<11; x++) {
         print(form.format(brightness(FIL.pixels[u+(y*CAM_W)+x])) + " , ");
         }
         println();
         println();
         }
         println("-------------------------------------------------------------------------------");
         */

        wflag = false;//while文から抜ける
      }
    }
  }

  //FIL.updatePixels();
  //image(FIL, CAM_W, CAM_H);

  if (vector.size() >= 3) {

    //近い点同士を結合させる(最初と最後の点も結合させたいけど、後で考える)
    for (int i=0; i<=vector.size()-2; i++) {//vector.capacity()でもいいかも
      int x_1 = new Integer(vector.elementAt(i).toString()) % CAM_W;
      int y_1 = new Integer(vector.elementAt(i).toString()) / CAM_W;
      int x_2 = new Integer(vector.elementAt(i+1).toString()) % CAM_W;
      int y_2 = new Integer(vector.elementAt(i+1).toString()) / CAM_W;
      int r = round( dist(x_1, y_1, x_2, y_2) ); //２点間の距離を求める
      if ( r<15) {//2点間の距離が20ピクセルより低ければ結合する
        vector.setElementAt( (y_1+y_2)/2*CAM_W + (x_1+x_2)/2, i);//２つの点の中点に新しい点を作成。新しい点の座標を格納
        vector.removeElementAt(i+1);//結合したのでもう一つの点は削除する
      }
      if (i == vector.size()-2) {//最後の２つ前のマーカーのときだけ、最後のマーカーと最初のマーカーの距離を考える
        x_1 = new Integer(vector.elementAt(i+1).toString()) % CAM_W;
        y_1 = new Integer(vector.elementAt(i+1).toString()) / CAM_W;
        x_2 = new Integer(vector.elementAt(0).toString()) % CAM_W;
        y_2 = new Integer(vector.elementAt(0).toString()) / CAM_W;
        r = round( dist(x_1, y_1, x_2, y_2) ); //２点間の距離を求める
        if (r<15) {
          vector.setElementAt( (y_1+y_2)/2*CAM_W + (x_1+x_2)/2, i+1);//２つの点の中点に新しい点を作成。新しい点の座標を格納
          vector.removeElementAt(0);//結合したのでもう一つの点は削除する
        }
      }
    }
    for (int i=0; i<vector.size(); i++) {
      noStroke();
      fill(0, 100, 100);
      ellipse( new Integer(vector.elementAt(i).toString())%CAM_W, new Integer(vector.elementAt(i).toString())/CAM_W, 5, 5);
    }
  }



  //各点の角度を求める
  if (vector.size() >= 3) {//vecotrに格納されているマーカーが３つ以上のときだけ処理を行う。２つ以下の場合はarrayエラーがでる。
    int[] Degree = new int[vector.size()];
    int A, B, C;//座標を格納する
    int yubi_count=0;
    for (int i=0; i<vector.size(); i++) {
      if (i==0) {//最初の点のとき
        A = new Integer(vector.firstElement().toString());//０番目の座標
        B = new Integer(vector.lastElement().toString());//最後の点の座標
        C = new Integer(vector.elementAt(1).toString());//1番目の座標
      } 
      else if (i == vector.size()-1) {//最後の点のとき
        A = new Integer(vector.lastElement().toString());//最後の点の座標
        B = new Integer(vector.elementAt(i-1).toString());//最後から2番目の座標
        C = new Integer(vector.firstElement().toString());//０番目の座標
      }  
      else {//それ以外のとき
        A = new Integer(vector.elementAt(i).toString());
        B = new Integer(vector.elementAt(i-1).toString());
        C = new Integer(vector.elementAt(i+1).toString());
      }

      int a_x = A%CAM_W, a_y = A/CAM_W;
      int b_x = B%CAM_W, b_y = B/CAM_W;
      int c_x = C%CAM_W, c_y = C/CAM_W;
      float a = dist(b_x, b_y, c_x, c_y);
      float b = dist(a_x, a_y, c_x, c_y);
      float c = dist(a_x, a_y, b_x, b_y);
      Degree[i] = round(degrees(acos((sq(b) + sq(c) - sq(a)) / (2*b*c))));//余弦定理

      //////////////
      //注目マーカーの角度が鋭角、かつ両サイドのマーカーの中点が手領域（白ピクセル）である、かつ最下線上のマーカーではないとき
      //ただし、今回は最下線じゃなくて(a_y<CAM_H-10)くらいにしておく
      if ( Degree[i] < 90  &&  brightness(Quants.pixels[(b_y+c_y)/2*CAM_W + (b_x+c_x)/2]) == 100  &&  a_y<CAM_H-10  &&  a_y>10  &&  a_x>10) {
        if (togire_flag==false) {//途切れがなく周回できたとき
          noStroke();
          fill(180, 100, 100);
          ellipse(a_x, a_y, 10, 10);
          yubi_count++;
        }
        //途切れがある場合は,最初と最後のマーカーは鋭角になっても指先として認識しないようにする
        else if ( togire_flag==true   &&   i!=0   &&   i!=vector.size()-1) {
          noStroke();
          fill(180, 100, 100);
          ellipse( a_x, a_y, 10, 10);
          yubi_count++;
        }
      }
      ///////////////
    }


    /////////
    switch(yubi_count) {//指の本数（０〜５本で表す)。
    case 0:
      FING = 0;
      //println("yubi count = " + FING);
      break;

    case 1:
      FING = 1;
      //println("yubi count = " + FING);
      break;

    case 2:
      FING = 2;
      //println("yubi count = " + FING);
      break;

    case 3:
      FING = 3;
      //println("yubi count = " + FING);
      break;

    case 4:
      FING = 4;
      //println("yubi count = " + FING);
      break;

    case 5:
      FING = 5;
      //println("yubi count = " + FING);
      break;

    default :
      FING = 6;
      println("yubi count = unknown");
      break;
    }
    /////////
  }
  //println("4lenght = "+((squ_x2-squ_x1)*2+(squ_y2-squ_y1)*2) );
  //println("rin/4 = " + (float)rinkaku_pix/((squ_x2-squ_x1)*2+(squ_y2-squ_y1)*2) ) ;
  return FING;
}//Yubiおわり



///////////////////////////////////////////////////////////////////////////////////////
void Recognition() {

  try {
    float aspect_ratio = (float)(squ_x2-squ_x1)/(squ_y2-squ_y1);//縦横比を求める
    float pixel_ratio = (float)grav_count/black_pix;//白黒ピクセル比を求める
    float outline_ratio = (float)rinkaku_pix/((squ_x2-squ_x1)*2+(squ_y2-squ_y1)*2);//四辺輪郭比を求める
    int moji_number = 0;


    if (ana==1) {//穴があるとき
      if (position == 2) {//手首が左にあるとき
        moji_number = 32;//me
      }
      else {//それ以外（手首が下にあるとき）
        moji_number = 5;//o
      }
    }
    else if (position == 1) {//穴がない、かつ手首が上にあるとき
      if (finger==0) {
        moji_number = 4;//e
      }
      else if (finger==1) {
        moji_number = 1;//a
        /*float e_diff  = Math.abs(0.72021866-aspect_ratio) + Math.abs(1.5398657-pixel_ratio) + Math.abs(0.89685726-outline_ratio);
         float na_diff = Math.abs(0.48536223-aspect_ratio) + Math.abs(1.1587952-pixel_ratio) + Math.abs(1.0479265-outline_ratio);
         float hu_diff = Math.abs(0.7023256-aspect_ratio) + Math.abs(0.7718458-pixel_ratio) + Math.abs(0.8770492-outline_ratio);
         float he_diff = Math.abs(0.6940418-aspect_ratio) + Math.abs(1.1741477-pixel_ratio) + Math.abs(1.0104398-outline_ratio);
         float minn1 = Math.min(e_diff, na_diff);
         minn1 = Math.min(minn1, hu_diff);
         minn1 = Math.min(minn1, he_diff);
         if (minn1==e_diff) {
         moji_number = 4;//e
         }
         else if (minn1==na_diff) {
         moji_number = 21;//na
         }
         else if (minn1==hu_diff) {
         moji_number = 26;//hu
         }
         else {
         moji_number = 27;//he
         }*/
      }
      else if (finger==2) {
        float na_diff = Math.abs(0.48536223-aspect_ratio) + Math.abs(1.1587952-pixel_ratio) + Math.abs(1.0479265-outline_ratio);
        float hu_diff = Math.abs(0.7023256-aspect_ratio) + Math.abs(0.7718458-pixel_ratio) + Math.abs(0.8770492-outline_ratio);
        float he_diff = Math.abs(0.6940418-aspect_ratio) + Math.abs(1.1741477-pixel_ratio) + Math.abs(1.0104398-outline_ratio);
        //float ma_diff = Math.abs(0.5534883-aspect_ratio) + Math.abs(1.7180015-pixel_ratio) + Math.abs(1.2000998-outline_ratio);
        float minn1 = Math.min(na_diff, hu_diff);
        minn1 = Math.min(minn1, he_diff);
        if (minn1==na_diff) {
          moji_number = 21;//na
        }
        else if (minn1==hu_diff) {
          moji_number = 26;//hu
        }
        else if (minn1==he_diff) {
          moji_number = 27;//he
        }
      }
      else if (finger==3) {
        float su_diff = Math.abs(0.7255149-aspect_ratio) + Math.abs(0.8285978-pixel_ratio) + Math.abs(1.0035759-outline_ratio);
        float ma_diff = Math.abs(0.5534883-aspect_ratio) + Math.abs(1.7180015-pixel_ratio) + Math.abs(1.2000998-outline_ratio);
        float minn1 = Math.min(su_diff, ma_diff);
        if (minn1==su_diff) {
          moji_number = 13;//su
        }
        else {
          moji_number = 29;//ma
        }
      }
      else if (finger==4) {
        //moji_number = 24;//ne
      }
      else if (finger==5) {
        moji_number = 24;//ne
      }
      else {
        //moji_number = 24;//ne
      }
    }

    else if (position == 2) {//穴がない、かつ手首が左にあるとき
      if (finger==0) {
        //moji_number = 8;//ku
      }
      else if (finger==1) {
        //float a_diff  = Math.abs(0.747142-aspect_ratio) + Math.abs(1.0815672-pixel_ratio) + Math.abs(0.9355138-outline_ratio);
        float ku_diff = Math.abs(1.3079646-aspect_ratio) + Math.abs(0.73359114-pixel_ratio) + Math.abs(0.9004366-outline_ratio);
        float nu_diff = Math.abs(1.3938239-aspect_ratio) + Math.abs(0.59821594-pixel_ratio) + Math.abs(0.7578084-outline_ratio);
        float minn1 = Math.min(ku_diff, nu_diff);
        //minn1 = Math.min(minn1, nu_diff);
        if (minn1==ku_diff) {
          moji_number = 8;//ku
        }
        //else if (minn1==nu_diff) {
        //moji_number = 23;//nu
        //}
        else {
          moji_number = 23;//nu
        }
      }
      else if (finger==2) {
        //float ku_diff = Math.abs(1.3079646-aspect_ratio) + Math.abs(0.73359114-pixel_ratio) + Math.abs(0.9004366-outline_ratio);
        float ni_diff = Math.abs(2.3498719-aspect_ratio) + Math.abs(1.7869077-pixel_ratio) + Math.abs(1.073826-outline_ratio);
        float mu_diff = Math.abs(1.4000319-aspect_ratio) + Math.abs(0.6132545-pixel_ratio) + Math.abs(0.84338844-outline_ratio);
        float minn1 = Math.min(ni_diff, mu_diff);
        //minn1 = Math.min(minn1, mu_diff);
        if (minn1==ni_diff) {
          moji_number = 22;//ni
        }
        else if (minn1==mu_diff) {
          moji_number = 31;//mu
        }
        else {
          //moji_number = 31;//mu
          //moji_number = 0;//??
        }
      }
      else if (finger==3) {
        moji_number = 30;//mi
        /*float mi_diff = Math.abs(2.1202674-aspect_ratio) + Math.abs(1.0774854-pixel_ratio) + Math.abs(1.0973175-outline_ratio);
         float mu_diff = Math.abs(1.4000319-aspect_ratio) + Math.abs(0.6132545-pixel_ratio) + Math.abs(0.84338844-outline_ratio);
         float minn1 = Math.min(mi_diff, mu_diff);
         if (minn1==mi_diff) {
         moji_number = 30;//mi
         }
         else {
         moji_number = 31;//mu
         }*/
      }
      else if (finger==4) {
        moji_number = 35;//yo
      }
      else if (finger==5) {
        //moji_number = 0;//??
      }
      else {
        //moji_number = 0;//??
      }
    }

    else if (position == 3) {//穴がない、かつ手首が下にあるとき
      if (finger==0) {
        float e_diff   = Math.abs(0.72021866-aspect_ratio) + Math.abs(1.5398657-pixel_ratio) + Math.abs(0.89685726-outline_ratio);
        float ke_diff  = Math.abs(0.44620854-aspect_ratio) + Math.abs(2.1477056-pixel_ratio) + Math.abs(0.8418763-outline_ratio);
        //float ko_diff  = Math.abs(0.7981844-aspect_ratio) + Math.abs(0.9456117-pixel_ratio) + Math.abs(0.8462824-outline_ratio);
        float sa_diff  = Math.abs(0.7054955-aspect_ratio) + Math.abs(1.7693343-pixel_ratio) + Math.abs(0.8664567-outline_ratio);
        float ho_diff  = Math.abs(0.6505833-aspect_ratio) + Math.abs(2.5369961-pixel_ratio) + Math.abs(0.80654-outline_ratio);
        float minn1 = Math.min(e_diff, ke_diff);
        //minn1 = Math.min(minn1, ko_diff);
        minn1 = Math.min(minn1, sa_diff);
        minn1 = Math.min(minn1, ho_diff);
        if (minn1==e_diff) {
          moji_number = 4;//e
        }
        else if (minn1==ke_diff) {
          moji_number = 9;//ke
        }
        //else if (minn1==ko_diff) {
        //moji_number = 10;//ko
        //}
        else if (minn1==sa_diff) {
          moji_number = 11;//sa
        }
        else {
          //moji_number = 28;//ho
          moji_number = 0;//??
        }
      }
      else if (finger==1) {
        float a_diff   = Math.abs(0.747142-aspect_ratio) + Math.abs(1.0815672-pixel_ratio) + Math.abs(0.9355138-outline_ratio);
        float i_diff   = Math.abs(0.6746239-aspect_ratio) + Math.abs(0.99038994-pixel_ratio) + Math.abs(0.8694885-outline_ratio);
        float u_diff   = Math.abs(0.38125417-aspect_ratio) + Math.abs(1.929859-pixel_ratio) + Math.abs(0.9271537-outline_ratio);
        //float e_diff   = Math.abs(0.72021866-aspect_ratio) + Math.abs(1.5398657-pixel_ratio) + Math.abs(0.89685726-outline_ratio);
        float ko_diff  = Math.abs(0.7981844-aspect_ratio) + Math.abs(0.9456117-pixel_ratio) + Math.abs(0.8462824-outline_ratio);
        float se_diff  = Math.abs(0.45170203-aspect_ratio) + Math.abs(1.3920679-pixel_ratio) + Math.abs(0.8330479-outline_ratio);
        float so_diff  = Math.abs(0.6826243-aspect_ratio) + Math.abs(1.2781236-pixel_ratio) + Math.abs(0.7974287-outline_ratio);
        float ta_diff  = Math.abs(0.4565698-aspect_ratio) + Math.abs(1.4197602-pixel_ratio) + Math.abs(0.8750363-outline_ratio);
        float ti_diff  = Math.abs(0.53453374-aspect_ratio) + Math.abs(1.3251731-pixel_ratio) + Math.abs(0.901693-outline_ratio);
        float te_diff  = Math.abs(0.6750771-aspect_ratio) + Math.abs(1.1697972-pixel_ratio) + Math.abs(0.8590297-outline_ratio);
        float to_diff  = Math.abs(0.41022488-aspect_ratio) + Math.abs(2.01776-pixel_ratio) + Math.abs(0.8690354-outline_ratio);
        float hi_diff  = Math.abs(0.49451107-aspect_ratio) + Math.abs(1.0378451-pixel_ratio) + Math.abs(0.8369273-outline_ratio);
        //float ho_diff  = Math.abs(0.6505833-aspect_ratio) + Math.abs(2.5369961-pixel_ratio) + Math.abs(0.80654-outline_ratio);
        float ra_diff  = Math.abs(0.43368515-aspect_ratio) + Math.abs(1.514196-pixel_ratio) + Math.abs(0.8584369-outline_ratio);
        float minn1 = Math.min(a_diff, i_diff);
        minn1 = Math.min(minn1, u_diff);
        //minn1 = Math.min(minn1, e_diff);
        minn1 = Math.min(minn1, ko_diff);
        minn1 = Math.min(minn1, se_diff);
        minn1 = Math.min(minn1, so_diff);
        minn1 = Math.min(minn1, ta_diff);
        minn1 = Math.min(minn1, ti_diff);
        minn1 = Math.min(minn1, te_diff);
        minn1 = Math.min(minn1, to_diff);
        minn1 = Math.min(minn1, hi_diff);
        //minn1 = Math.min(minn1, ho_diff);
        minn1 = Math.min(minn1, ra_diff);
        if (minn1==a_diff) {
          moji_number = 1;//a
        }
        else if (minn1==i_diff) {
          moji_number = 2;//i
        }
        else if (minn1==u_diff) {
          moji_number = 3;//u
        }
        //else if (minn1==e_diff) {
        //moji_number = 4;//e
        //}
        else if (minn1==ko_diff) {
          moji_number = 10;//ko
        }
        else if (minn1==se_diff) {
          moji_number = 14;//se
        }
        else if (minn1==so_diff) {
          moji_number = 15;//so
        }
        else if (minn1==ta_diff) {
          moji_number = 16;//ta
        }
        else if (minn1==ti_diff) {
          moji_number = 17;//ti
        }
        else if (minn1==te_diff) {
          moji_number = 19;//te
        }
        else if (minn1==to_diff) {
          moji_number = 20;//to
        }
        else if (minn1==hi_diff) {
          moji_number = 25;//hi
        }
        //else if (minn1==ho_diff) {
        //moji_number = 28;//ho
        //}
        else {
          moji_number = 36;//ra
          //moji_number = 0;//??
        }
      }
      else if (finger==2) {
        //float u_diff   = Math.abs(0.38125417-aspect_ratio) + Math.abs(1.929859-pixel_ratio) + Math.abs(0.9271537-outline_ratio);
        float ka_diff  = Math.abs(0.4183045-aspect_ratio) + Math.abs(1.8435998-pixel_ratio) + Math.abs(0.963114-outline_ratio);
        float ki_diff  = Math.abs(0.6579926-aspect_ratio) + Math.abs(0.96811765-pixel_ratio) + Math.abs(0.98166543-outline_ratio);
        //float ko_diff  = Math.abs(0.7981844-aspect_ratio) + Math.abs(0.9456117-pixel_ratio) + Math.abs(0.8462824-outline_ratio);
        float tu_diff  = Math.abs(0.53918886-aspect_ratio) + Math.abs(1.4366964-pixel_ratio) + Math.abs(0.999084-outline_ratio);
        //float te_diff  = Math.abs(0.6750771-aspect_ratio) + Math.abs(1.1697972-pixel_ratio) + Math.abs(0.8590297-outline_ratio);
        //float to_diff  = Math.abs(0.41022488-aspect_ratio) + Math.abs(2.01776-pixel_ratio) + Math.abs(0.8690354-outline_ratio);
        float ya_diff  = Math.abs(0.88680375-aspect_ratio) + Math.abs(1.005073-pixel_ratio) + Math.abs(0.9237286-outline_ratio);
        //float ra_diff  = Math.abs(0.43368515-aspect_ratio) + Math.abs(1.514196-pixel_ratio) + Math.abs(0.8584369-outline_ratio);
        float re_diff  = Math.abs(0.7231636-aspect_ratio) + Math.abs(0.63103735-pixel_ratio) + Math.abs(0.8204338-outline_ratio);
        float ro_diff  = Math.abs(0.5026291-aspect_ratio) + Math.abs(1.2814188-pixel_ratio) + Math.abs(1.0048714-outline_ratio);
        //float minn1 = Math.min(u_diff, ka_diff);
        float minn1 = Math.min(ka_diff, ki_diff);
        //minn1 = Math.min(minn1, ki_diff);
        //minn1 = Math.min(minn1, ko_diff);
        minn1 = Math.min(minn1, tu_diff);
        //minn1 = Math.min(minn1, te_diff);
        //minn1 = Math.min(minn1, to_diff);
        minn1 = Math.min(minn1, ya_diff);
        //minn1 = Math.min(minn1, ra_diff);
        minn1 = Math.min(minn1, re_diff);
        minn1 = Math.min(minn1, ro_diff);
        //if (minn1==u_diff) {
        //moji_number = 3;//u
        //}
        if (minn1==ka_diff) {
          moji_number = 6;//ka
        }
        else if (minn1==ki_diff) {
          moji_number = 7;//ki
        }
        //else if (minn1==ko_diff) {
        //moji_number = 10;//ko
        //}
        else if (minn1==tu_diff) {
          moji_number = 18;//tu
        }
        //else if (minn1==te_diff) {
        //moji_number = 19;//te
        //}
        //else if (minn1==to_diff) {
        //moji_number = 20;//to
        //}
        else if (minn1==ya_diff) {
          moji_number = 33;//ya
        }
        //else if (minn1==ra_diff) {
        //moji_number = 36;//ra
        //}
        else if (minn1==re_diff) {
          moji_number = 38;//re
        }
        else {
          moji_number = 39;//ro
          //moji_number = 0;//??
        }
      }
      else if (finger==3) {
        float si_diff  = Math.abs(0.89110947-aspect_ratio) + Math.abs(0.7742661-pixel_ratio) + Math.abs(0.97366464-outline_ratio);
        float yu_diff  = Math.abs(0.4867434-aspect_ratio) + Math.abs(2.0884428-pixel_ratio) + Math.abs(1.1885709-outline_ratio);
        float ru_diff  = Math.abs(0.6982908-aspect_ratio) + Math.abs(0.8689597-pixel_ratio) + Math.abs(1.0345209-outline_ratio);
        //float re_diff  = Math.abs(0.7231636-aspect_ratio) + Math.abs(0.63103735-pixel_ratio) + Math.abs(0.8204338-outline_ratio);
        float wa_diff  = Math.abs(0.48468488-aspect_ratio) + Math.abs(1.761718-pixel_ratio) + Math.abs(1.2726007-outline_ratio);
        float minn1 = Math.min(si_diff, yu_diff);
        minn1 = Math.min(minn1, ru_diff);
        //minn1 = Math.min(minn1, re_diff);
        minn1 = Math.min(minn1, wa_diff);
        if (minn1==si_diff) {
          moji_number = 12;//si
        }
        else if (minn1==yu_diff) {
          moji_number = 34;//yu
        }
        else if (minn1==ru_diff) {
          moji_number = 37;//ru
        }
        //else if (minn1==re_diff) {
        //moji_number = 38;//re
        //}
        else {
          moji_number = 40;//wa
        }
      }
      else if (finger==4) {
        //moji_number = 37;//ru
      }
      else {
        //moji_number = 37;//ru
        //moji_number = 0;//??
      }
    }
    else { //それ以外（穴がない、手首の位置不明のとき）
      moji_number = 0;//??
      //println("unknown");
    }

    PImage moji = loadImage(moji_number + ".jpg");//文字画像の表示（１〜４０）
    image(moji, CAM_W*2+15, CAM_H+30);
    PFont font = loadFont("rec_24.vlw");//作成したフォントファイルを読み込む。
    textFont(font);//以降のフォント、サイズを上で読み込んだfontにする。
    fill(0, 0, 0);//文字の色を黒とする
    text("Recognition_result", CAM_W*2+60, CAM_H+20);//文字の表示

    //文字画像の横に文字の名前を表示する。
    switch (moji_number) {
    case  1:
      text("a", CAM_W*2+180, CAM_H+200);
      break;
    case  2:
      text("i", CAM_W*2+180, CAM_H+200);
      break;
    case  3:
      text("u", CAM_W*2+180, CAM_H+200);
      break;
    case  4:
      text("e", CAM_W*2+180, CAM_H+200);
      break;
    case  5:
      text("o", CAM_W*2+180, CAM_H+200);
      break;
    case  6:
      text("ka", CAM_W*2+180, CAM_H+200);
      break;
    case  7:
      text("ki", CAM_W*2+180, CAM_H+200);
      break;
    case  8:
      text("ku", CAM_W*2+180, CAM_H+200);
      break;
    case  9:
      text("ke", CAM_W*2+180, CAM_H+200);
      break;
    case  10:
      text("ko", CAM_W*2+180, CAM_H+200);
      break;
    case  11:
      text("sa", CAM_W*2+180, CAM_H+200);
      break;
    case  12:
      text("si", CAM_W*2+180, CAM_H+200);
      break;
    case  13:
      text("su", CAM_W*2+180, CAM_H+200);
      break;
    case  14:
      text("se", CAM_W*2+180, CAM_H+200);
      break;
    case  15:
      text("so", CAM_W*2+180, CAM_H+200);
      break;
    case  16:
      text("ta", CAM_W*2+180, CAM_H+200);
      break;
    case  17:
      text("ti", CAM_W*2+180, CAM_H+200);
      break;
    case  18:
      text("tu", CAM_W*2+180, CAM_H+200);
      break;
    case  19:
      text("te", CAM_W*2+180, CAM_H+200);
      break;
    case  20:
      text("to", CAM_W*2+180, CAM_H+200);
      break;
    case  21:
      text("na", CAM_W*2+180, CAM_H+200);
      break;
    case  22:
      text("ni", CAM_W*2+180, CAM_H+200);
      break;
    case  23:
      text("nu", CAM_W*2+180, CAM_H+200);
      break;
    case  24:
      text("ne", CAM_W*2+180, CAM_H+200);
      break;
    case  25:
      text("hi", CAM_W*2+180, CAM_H+200);
      break;
    case  26:
      text("hu", CAM_W*2+180, CAM_H+200);
      break;
    case  27:
      text("he", CAM_W*2+180, CAM_H+200);
      break;
    case  28:
      text("ho", CAM_W*2+180, CAM_H+200);
      break;
    case  29:
      text("ma", CAM_W*2+180, CAM_H+200);
      break;
    case  30:
      text("mi", CAM_W*2+180, CAM_H+200);
      break;
    case  31:
      text("mu", CAM_W*2+180, CAM_H+200);
      break;
    case  32:
      text("me", CAM_W*2+180, CAM_H+200);
      break;
    case  33:
      text("ya", CAM_W*2+180, CAM_H+200);
      break;
    case  34:
      text("yu", CAM_W*2+180, CAM_H+200);
      break;
    case  35:
      text("yo", CAM_W*2+180, CAM_H+200);
      break;
    case  36:
      text("ra", CAM_W*2+180, CAM_H+200);
      break;
    case  37:
      text("ru", CAM_W*2+180, CAM_H+200);
      break;
    case  38:
      text("re", CAM_W*2+180, CAM_H+200);
      break;
    case  39:
      text("ro", CAM_W*2+180, CAM_H+200);
      break;
    case  40:
      text("wa", CAM_W*2+180, CAM_H+200);
      break;
    default:
      text("??", CAM_W*2+180, CAM_H+200);
      break;
    }


    /*try {
     float aspect_ratio = (float)(squ_x2-squ_x1)/(squ_y2-squ_y1);//縦横比を求める
     float pixel_ratio = (float)grav_count/black_pix;//白黒ピクセル比を求める
     float outline_ratio = (float)rinkaku_pix/((squ_x2-squ_x1)*2+(squ_y2-squ_y1)*2);//四辺輪郭比を求める
     println("aspect = " + aspect_ratio + ", pixel = " + pixel_ratio + ", outline = " + outline_ratio);
     }
     catch(ArithmeticException e) {
     println(e);
     }
     */
  }
  catch(ArithmeticException e) {
    println(e);
  }
}
//////////////////////////////////////////////////////////////////////////////



//イベントハンドラ
/////////////////////////////////////////////////////////////////
//カメラの画像が更新されたときの処理
void captureEvent(Capture CAMERA) {
  //新たな画像をCAMERAに読み込む
  CAMERA.read();
}
/////////////////////////////////////////////////////////////////
//マウスがクリックされたときの処理
void mousePressed() {
  int x=mouseX;
  int y=mouseY;
  int pix_pos = y * width + x;
  /////////////////////////////////////////////////////////////////
  // マウスでキャプチャした位置のカラー画像を取得
  loadPixels();

  println("x :" + x + "  y :" + y + "  pix_pos : " + pix_pos);
  print("  red pix : " + red(pixels[pix_pos]));
  print("  blue pix : " + blue(pixels[pix_pos]));
  println("  green pix : " + green(pixels[pix_pos]));
  println("  hue(色合い) pix : " + hue(pixels[pix_pos]));
  print("  saturation(彩度) pix : " + saturation(pixels[pix_pos]));
  println("  brightness(輝度) pix : " + brightness(pixels[pix_pos]));
}
/////////////////////////////////////////////////////////////////
//キーが押された時の処理
void keyPressed() {

  //色相値の変更
  switch(key) {

    //aが押された場合色相の上限閾値をマイナス
  case 'a':
    HUE_TH_MAX -= 1;
    if (HUE_TH_MAX < 0) {
      HUE_TH_MAX = H_MAX - 1;
    }
    println("HUE_TH_MAX(色相の上限値) = " + HUE_TH_MAX);
    break;

    //sが押された場合色相の上限閾値をプラス
  case 's':
    HUE_TH_MAX += 1;
    if (HUE_TH_MAX >= H_MAX) {
      HUE_TH_MAX = 0;
    }
    println("HUE_TH_MAX(色相の上限値) = " + HUE_TH_MAX);
    break;

    //zが押された場合色相の下限閾値をマイナス
  case 'z':
    HUE_TH_MIN -= 1;
    if (HUE_TH_MIN < 0) {
      HUE_TH_MIN = H_MAX - 1;
    }
    println("HUE_TH_MIN(色相の下限値) = " + HUE_TH_MIN);
    break;

    //xが押された場合色相の下限閾値をプラス
  case 'x':
    HUE_TH_MIN += 1;
    if (HUE_TH_MIN >= H_MAX) {
      HUE_TH_MIN = 0;
    }
    println("HUE_TH_MIN(色相の下限値) = " + HUE_TH_MIN);
    break;
  }//switch(key)文の終わり


  //彩度値の変更
  switch(key) {
    //dが押された場合彩度の上限値をマイナス
  case 'd':
    SATU_TH_MAX -= 1;
    println("SATU_TH_MAX = " + SATU_TH_MAX);
    break;
    //fが押された場合彩度の上限値をプラス
  case 'f':
    SATU_TH_MAX += 1;
    println("SATU_TH_MAX = " + SATU_TH_MAX);
    break;    
    //cが押された場合彩度の下限値をマイナス
  case 'c':
    SATU_TH_MIN -= 1;
    println("SATU_TH_MIN = " + SATU_TH_MIN);
    break;
    //vが押された場合彩度の上限値をプラス
  case 'v':
    SATU_TH_MIN += 1;
    println("SATU_TH_MIN = " + SATU_TH_MIN);
    break;
  }

  //明度値の変更
  switch(key) {
    //gが押された場合明度の上限値をマイナス
  case 'g':
    BRI_TH_MAX -= 1;
    println("BRI_TH_MAX = " + BRI_TH_MAX);
    break;
    //hが押された場合明度の上限値をプラス
  case 'h':
    BRI_TH_MAX += 1;
    println("BRI_TH_MAX = " + BRI_TH_MAX);
    break;    
    //bが押された場合明度の下限値をマイナス
  case 'b':
    BRI_TH_MIN -= 1;
    println("BRI_TH_MIN = " + BRI_TH_MIN);
    break;
    //nが押された場合彩度の上限値をプラス
  case 'n':
    BRI_TH_MIN += 1;
    println("BRI_TH_MIN = " + BRI_TH_MIN);
    break;
  case 'm':  // nakahodo メディアンフィルター
    mflag = !mflag;
    break;

  case 'y':  //指認識
    yflag = !yflag;
    //Yubi(Result);
    break;


  case 'l':  //ラベリング
    lflag = !lflag;
    break;

  case 't':  //sikaku, grav, tekubi
    tflag = !tflag;
    break;

  case 'r': //認識開始
    rflag = !rflag;
    break;

  case 'p': //debug
    pflag = !pflag;
    break;
  }
}

