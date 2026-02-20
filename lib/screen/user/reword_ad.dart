import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewordAd extends StatefulWidget {
  const RewordAd({super.key});

  @override
  State<RewordAd> createState()=>_RewordAdState();
}

class _RewordAdState extends State<RewordAd>{

  BannerAd? _bannerAd;
  bool _isBannerReady=false;

  void loadBannerAd(){
    _bannerAd=BannerAd(
      size:AdSize.banner,
      adUnitId:'ca-app-pub-3940256099942544/6300978111',
      request:const AdRequest(),
      listener:BannerAdListener(
        onAdLoaded:(ad){
          setState(()=>_isBannerReady=true);
        },
        onAdFailedToLoad:(ad,error){
          ad.dispose();
          debugPrint(error.toString());
        },
      ),
    );
    _bannerAd!.load();
  }

  RewardedAd? _rewardedAd;

  void loadRewardedAd(){
    RewardedAd.load(
      adUnitId:'ca-app-pub-3940256099942544/5224354917',
      request:const AdRequest(),
      rewardedAdLoadCallback:RewardedAdLoadCallback(
        onAdLoaded:(ad){
          _rewardedAd=ad;
          debugPrint("Rewarded Loaded");
        },
        onAdFailedToLoad:(error){
          debugPrint(error.toString());
        },
      ),
    );
  }

  void showRewardedAd(){
    if(_rewardedAd==null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:Text("Ad not ready yet"),
        ),
      );
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward:
          (AdWithoutView ad,RewardItem reward){

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:Text("🎉 You Earned Coins!"),
          ),
        );
      },
    );

    _rewardedAd=null;
    loadRewardedAd();
  }

  @override
  void initState(){
    super.initState();
    loadBannerAd();
    loadRewardedAd();
  }

  @override
  void dispose(){
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(
        title:const Text("Earn Coins"),
      ),
      body:Column(
        children:[
          Expanded(
            child:Center(
              child:Padding(
                padding:const EdgeInsets.all(20),
                child:Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children:[
                    const Icon(
                      Icons.monetization_on,
                      size:90,
                      color:Colors.amber,
                    ),
                    const SizedBox(height:20),
                    const Text(
                      "Watch Ads & Earn Coins",
                      style:TextStyle(
                        fontSize:22,
                        fontWeight:FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height:15),
                    const Text(
                      "Watch a short video ad to earn rewards.",
                      textAlign:TextAlign.center,
                    ),
                    const SizedBox(height:30),
                    ElevatedButton.icon(
                      onPressed:showRewardedAd,
                      icon:
                      const Icon(Icons.play_arrow),
                      label:
                      const Text("Watch Ad"),
                      style:
                      ElevatedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:30,
                          vertical:15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if(_isBannerReady)
            SizedBox(
              width:_bannerAd!
                  .size.width
                  .toDouble(),
              height:_bannerAd!
                  .size.height
                  .toDouble(),
              child:
              AdWidget(ad:_bannerAd!),
            ),
        ],
      ),
    );
  }
}