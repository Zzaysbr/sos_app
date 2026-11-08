import java.lang.reflect.*;
public class Media3Selection {
 public static void main(String[] args)throws Exception {
  Class<?> fb=Class.forName("androidx.media3.common.Format$Builder");Object f=fb.getConstructor().newInstance();fb.getMethod("setSampleMimeType",String.class).invoke(f,"video/avc");fb.getMethod("setWidth",int.class).invoke(f,480);fb.getMethod("setHeight",int.class).invoke(f,270);fb.getMethod("setFrameRate",float.class).invoke(f,15f);Object format=fb.getMethod("build").invoke(f);
  Class<?> sb=Class.forName("androidx.media3.transformer.VideoEncoderSettings$Builder");Class<?> es=Class.forName("androidx.media3.transformer.EncoderSelector");Object selector=es.getField("DEFAULT").get(null);Class<?> ef=Class.forName("androidx.media3.transformer.DefaultEncoderFactory");Method target=null;for(Method m:ef.getDeclaredMethods()){if(m.getName().equals("resolveVideoEncoderConfiguration")){target=m;target.setAccessible(true);}}
  for(int mode:new int[]{2,1}) {
   Object settings=sb.getConstructor().newInstance();sb.getMethod("setBitrate",int.class).invoke(settings,1000000);sb.getMethod("setBitrateMode",int.class).invoke(settings,mode);settings=sb.getMethod("build").invoke(settings);
   Object result=target.invoke(null,format,settings,selector,true,true,false,false);
   System.out.println("mode="+mode+" media3_encoder_selection="+(result==null?"NONE":"SUPPORTED"));
  }
 }
}