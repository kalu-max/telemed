process.env.DB_DIALECT='sqlite';
process.env.DB_STORAGE=':memory:';
require('dotenv').config();
const {sequelize} = require('../server/config/database');
const {User,Doctor,Patient,Consultation,Message,CallLog,MediaFile,Billing} = require('../server/models');

(async ()=>{
  await sequelize.sync({force:true});
  try{
    const u = await User.create({userId:'u1',email:'a@a.com',password:'pw',name:'aa',role:'patient'});
    console.log('user created',u.toJSON());
    const p=await Patient.create({userId:'u1',gender:'other'});
    console.log('patient created',p.toJSON());
  }catch(e){
    console.error('error inserting patient', e);
  }
  process.exit(0);
})();