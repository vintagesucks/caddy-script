module.exports = {
  'Title' : function (client) {
    client
      .url('http://127.0.0.1:1337/phpmyadmin/')
      .waitForElementVisible('body', 1000)
      .assert.title('phpMyAdmin')
      .end();
  }
};
