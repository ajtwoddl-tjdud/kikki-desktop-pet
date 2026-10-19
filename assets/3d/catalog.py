"""One catalog shared by Blender rendering, atlas assembly and validation."""
SHEETS = [
 ('base','doongi',4,2,2),('blink','doongi-blink',4,2,2),
 ('look','doongi-look',4,2,2),('playful','doongi-playful',4,2,2),
 ('walkPose','doongi-walk',4,2,2),('back','doongi-back',4,2,2),
 ('rest','doongi-rest',6,3,2),('walk','doongi-walk-cycle',8,4,2),
 ('glance','kikki-walk-glance',8,4,2),('drop','doongi-phone-drop',4,2,2),
 ('pickup','doongi-pickup',4,2,2),('lift','kikki-lift-cycle',8,4,2),
 ('liftPose','doongi-lift',4,2,2),('transition','kikki-posture-transitions',12,4,3),
 ('camera','kikki-camera',8,4,2),('reels','kikki-reels-variety',12,4,3),
 ('smoke','kikki-smoking',4,2,2),('hairHeart','kikki-hair-heart',6,3,2),
 ('noodles','kikki-spicy-noodles',6,3,2),('extra','kikki-cymbals-stretch',8,4,2),
]

def cells(key,w,h,cols,rows):
    result=[]
    for i in range(cols*rows):
        r,c=divmod(i,cols)
        x0,x1=c*w//cols,(c+1)*w//cols; y0,y1=r*h//rows,(r+1)*h//rows
        if key=='lift':
            cuts=[0,462,887,1318,1774]; x0,x1=cuts[c]*w//1774,cuts[c+1]*w//1774
        if key=='transition':
            cuts=[[0,344,693,1062,1448],[0,368,729,1092,1448],[0,378,724,1086,1448]][r]
            x0,x1=cuts[c:c+2]; y0,y1=[0,436,770,1086][r:r+2]
        if key=='extra':
            cuts=[[0,467,877,1284,1774],[0,433,883,1352,1774]][r]
            x0,x1=cuts[c:c+2]; y0,y1=[0,530,887][r:r+2]
        if key=='reels':y0,y1=[0,406,748,1086][r:r+2]
        if key=='pickup' and i==0:x1+=13
        if key=='pickup' and i==1:x0+=13
        if key=='drop':
            split=int(w*.5263)
            if i in (0,2):x1=split
            if i==3:x0=split
        if key=='liftPose' and i==3:y0+=18
        result.append((x0,y0,x1,y1))
    return result
