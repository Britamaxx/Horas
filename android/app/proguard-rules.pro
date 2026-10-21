# Pertahankan metadata yang dapat diperlukan oleh library Android berbasis refleksi.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }