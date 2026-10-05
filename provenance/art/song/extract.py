from PIL import Image,ImageDraw
from pathlib import Path
root=Path(__file__).parent
expressions={'standing':['neutral','smile','thoughtful'],'seated':['neutral','smile','sad'],'action':['neutral','surprised','determined']}
contact=Image.new('RGB',(768,1320),'#86bd9a');d=ImageDraw.Draw(contact)
for row,(pose,exprs) in enumerate(expressions.items()):
 im=Image.open(root/'originals'/f'song_{pose}_sheet.png')
 for i,expr in enumerate(exprs):
  tile=im.crop((i*512,0,(i+1)*512,1024)); box=tile.getchannel('A').getbbox();print(pose,expr,box)
  # Approved asset extraction only: crop to alpha box, contain preserving proportions, transparent padding.
  tile=tile.crop(box);tile.thumbnail((472,840),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',(512,880));out.alpha_composite(tile,((512-tile.width)//2,860-tile.height));out.save(root/'characters'/f'song_{pose}_{expr}.png')
  small=out.resize((256,440),Image.Resampling.LANCZOS);contact.paste(small,(i*256,row*440),small);d.text((i*256+10,row*440+5),f'{pose}_{expr}',fill='black')
contact.save(root/'originals'/'song_contact_alpha_review.jpg',quality=94)
